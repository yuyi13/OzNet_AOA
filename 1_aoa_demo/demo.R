# source: https://stats.stackexchange.com/questions/61090/how-to-split-a-data-set-to-do-10-fold-cross-validation

# check if the required packages are installed
requiredPackages = c('terra', 'raster', 'caret', 'CAST', 'RColorBrewer')
for (k in requiredPackages){
    if (!require(k, character.only = TRUE)) install.packages(k, repos='https://cloud.r-project.org')
    library(k, character.only = TRUE)
}

# data paths
path2oznet   = '0_ancillary/OzNet_cleaned_data/'
path2static  = '0_ancillary/var_static/'
path2dynamic = '0_ancillary/var_dynamic/'
out_path     = '1_aoa_demo/'

# study period
Dates = seq(as.Date('2016-01-01'), as.Date('2019-12-31'), by='day') # training period

# read the study site list
oznet_valid = read.csv('0_ancillary/OzNet_study_sites.csv')

###################################
# train the model and calculate TDI
###################################

# prepare the training data
whole_df_train = data.frame(matrix(nrow=0,ncol=23))

for (t in 1:nrow(oznet_valid)){
    single_df_train = read.csv(paste0(path2oznet, 'OzNet_', oznet_valid$sitename[t], '_cleaned_data.csv'))
    # only choose data between 2016 and 2019
    single_df_train = single_df_train[which(as.Date(single_df_train$time) >= Dates[1] & as.Date(single_df_train$time) <= Dates[length(Dates)]),]
    single_df_train$fold = oznet_valid$iteration[t]
    whole_df_train  = rbind(whole_df_train, single_df_train)
}

# remove ndvi outliers
huge_ndvi_diff = which(abs(whole_df_train$ndvi_100m - whole_df_train$ndvi_500m) > 0.4)
if (length(huge_ndvi_diff) > 0) whole_df_train = whole_df_train[-huge_ndvi_diff,]
whole_df_train = na.omit(whole_df_train)

# Standard k-fold cross-validation can lead to considerable misinterpretation in spatial-temporal modelling tasks. 
# This function can be used to prepare a Leave-Location-Out, Leave-Time-Out or Leave-Location-and-Time-Out cross-validation 
# as target-oriented validation strategies for spatial-temporal prediction tasks. 
# https://hannameyer.github.io/CAST/reference/CreateSpacetimeFolds.html
# spatial_cv = CAST::CreateSpacetimeFolds(whole_df_train, spacevar = 'sitename', timevar = NA, k = 4, class = NA, seed=13)

# specify the index of folds
# this is a 4-fold spatial cross-validation
spatial_cv_idx = c()
for (i in 1:4){
    spatial_cv_idx[[i]] = which(whole_df_train$fold != i)
}

# specify the response variable and predictor variables
response_train   = whole_df_train[,4]
predictors_train = whole_df_train[,c(5:9,13:20)]

# we use xgb for demonstration because it is fast and easy
set.seed(13)
xgb.model = caret::train(x=predictors_train,
                         y=response_train,
                         method='xgbTree',
                         importance=TRUE,
                         trControl = trainControl(method='cv', index=spatial_cv_idx))
# save the trained model
saveRDS(xgb.model, file=paste0(out_path, 'xgb_model_caret_4fold_spatial_cv.rds'))

# train disimilarity index
xgb.tdi = trainDI(xgb.model); print(xgb.tdi)
saveRDS(xgb.tdi, file=paste0(out_path, 'xgb_tdi_caret_4fold_spatial_cv.rds'))

#############################################
# now apply the trained DI to spatial rasters
#############################################

# static layers
rst_dem  = rast(paste0(path2static, 'DEM_100m_resampled.tif'))
rst_awc  = rast(paste0(path2static, 'AWC_100m_resampled.tif'))
rst_clay = rast(paste0(path2static, 'CLY_100m_resampled.tif'))
rst_silt = rast(paste0(path2static, 'SLT_100m_resampled.tif'))
rst_sand = rast(paste0(path2static, 'SND_100m_resampled.tif'))

# dynamic layers
rst_alb  = rast(paste0(path2dynamic, 'ESTARFM_albedo_NBAR_cloudrm_20160205.tif'))
rst_lst  = rast(paste0(path2dynamic, 'ubESTARFM_LST_cloudrm_20160205.tif'))
rst_ndvi = rast(paste0(path2dynamic, 'ESTARFM_NDVI_NBAR_cloudrm_20160205.tif'))
rst_et   = rast(paste0(path2dynamic, 'CMRSET_Landsat_ET_2016_02_01.tif'))
rst_tavg = rast(paste0(path2dynamic, 'ANUClimate_v2-0_tavg_daily_20160205.tif'))
rst_vpd  = rast(paste0(path2dynamic, 'ANUClimate_v2-0_vpd_daily_20160205.tif'))
rst_srad = rast(paste0(path2dynamic, 'ANUClimate_v2-0_srad_daily_20160205.tif'))
rst_rain = rast(paste0(path2dynamic, 'ANUClimate_v2-0_rain_daily_20160205.tif'))

pred_stk = c(rst_dem, rst_awc, rst_clay, rst_silt, rst_sand, 
             rst_lst, rst_alb, rst_ndvi, rst_et,
             rst_tavg, rst_vpd, rst_srad, rst_rain)

names(pred_stk) = c('dem','awc','clay','silt','sand',
                    'lst_100m','albedo_100m','ndvi_100m','et_100m',
                    'tavg','vpd','srad','rain')

# predict SM
pred_sm = terra::predict(pred_stk, model=xgb.model, na.rm=TRUE)

# calculate AOA and DI of new data using pre-determined TDI
aoa_metric = aoa(newdata = pred_stk, trainDI = xgb.tdi)

sm_di  = aoa_metric$DI; sm_di[sm_di > 5] = 5; sm_di[sm_di < 0] = 0
sm_aoa = aoa_metric$AOA

# check output
print(aoa_metric)

#######################
# visualise the results
#######################

# colour ramps
SMcolours = colorRampPalette(c('white',"peru","orange","yellow","forestgreen",'deepskyblue','navy','black'))
spectralRamp = colorRampPalette(RColorBrewer::brewer.pal(11, 'Spectral'))

jpeg(paste0('figures/fig_aoa_demo.jpg'), width=1150, height=450)
m = cbind(1,2,3); layout(m); par(mar = c(0.5, 0.5, 4, 0.5))

# plot sm prediction
image(raster(pred_sm), zlim=c(0,0.5), col=SMcolours(64), xaxt='n', yaxt='n', xlab=NA, ylab=NA)
rect(146.06, -34.77, 146.16, -34.67, lwd=3)
rect(146.25, -35.02, 146.35, -34.92, lwd=3)
mtext('SM prediction', side=3, cex=2)

# plot di median
image(raster(sm_di), zlim=c(0,5), col=spectralRamp(64), xaxt='n', yaxt='n', xlab=NA, ylab=NA)
rect(146.06, -34.77, 146.16, -34.67, lwd=3)
rect(146.25, -35.02, 146.35, -34.92, lwd=3)
mtext('DI', side=3, cex=2)

legend('topleft', legend = paste0('Threshold = ', round(xgb.tdi$threshold, 2)), cex=2.5, bty='n')

# plot aoa mean
image(raster(sm_aoa), col=c('transparent', 'grey'), xaxt='n', yaxt='n', xlab=NA, ylab=NA)
rect(146.06, -34.77, 146.16, -34.67, lwd=3)
rect(146.25, -35.02, 146.35, -34.92, lwd=3)
mtext('AOA', side=3, cex=2)

aoa_perc = length(which(as.vector(sm_aoa) == 1))/length(as.vector(sm_aoa)) * 100
legend('topleft', legend = paste0('Area = ', round(aoa_perc, 1), '%'), cex=2.5, bty='n')

dev.off()
