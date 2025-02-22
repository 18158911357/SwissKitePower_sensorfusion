% Running the kalman filter for the vicon test

%---------------------------------------------
%Import DATA
%---------------------------------------------
%% Importing Xsens
fid_xsens_cal = fopen('x_test_2_4.txt');
[pos_X,vel_X, acc_X,gyro_X,magn_X,meas_time_X,counter_X,pos_counter_X] =import_Xsens(fid_xsens_cal);
%% Importing PixHawk
fid_pixhawk = fopen('p_test_2_4.txt');
[acc_P,gyro_P,magn_P,meas_time_P,counter_P]= import_PixHawk(fid_pixhawk);
%% Import vicon file
VI=csvread('positionlog_KiteBox_20.57.31.969.csv');


%------------------------
%bringing sensors and vicon together. NO NOISE added to vicon
%------------------------
%% deleting error measurements
[meas_time_X,acc_X,gyro_X,magn_X,counter_X]=delete_meas_error(10,273,meas_time_X,acc_X,gyro_X,magn_X,counter_X);
[meas_time_P,acc_P,gyro_P,magn_P,counter_P]=delete_meas_error(10,273,meas_time_P,acc_P,gyro_P,magn_P,counter_P);

%% VI posiotion and velocity + PixHawk
% dt_vicon=(344.8410-40.7830)/(336220-39660);
dt_vicon=0.001000;
meas_time_VI=VI(:,1).*dt_vicon;
meas_time_VI_new=meas_time_VI';
VI_new=VI';

for i=2:4
      pos_VI_p(i-1,:)=awgn(interp1(meas_time_VI_new+6.4920,VI_new(i,:),meas_time_P),-20);
end

Z_p=[pos_VI_p;zeros(3,size(meas_time_P,2));acc_P;gyro_P;magn_P];

counter_P_pv(1,1)=1;
for j=2:size(pos_VI_p,2)
    if pos_VI_p(1,j) == pos_VI_p(1,j-1) && pos_VI_p(2,j) == pos_VI_p(2,j-1) && pos_VI_p(3,j) == pos_VI_p(3,j-1);
        counter_P_pv(1,j)=j-1;
    else counter_P_pv(1,j)=j;
    end
end
counter_P_pv(2,1)=1;
for j=2:size(meas_time_P);
    counter_P_pv(j,2)=j;
end

counter_p_new=[counter_P_pv;counter_P];

%%
plot(meas_time_P,pos_VI_p(1,:),meas_time_P,acc_P(1,:),meas_time_P,acc_P(3,:)+1000,meas_time_P,magn_P(3,:));legend('position','accelerometerX','accelerometerZ','magnetometer');
%% VI position and velocity + Xsens

dt_vicon=0.00100;
meas_time_VI=VI(:,1).*dt_vicon;
meas_time_VI=meas_time_VI';
for i=2:4
     pos_VI_x(i-1,:)=awgn(interp1(meas_time_VI+6.4920,VI(:,i),meas_time_X),-20);
end

Z_x=[pos_VI_x;zeros(3,size(meas_time_X,2));acc_X;gyro_X;magn_X];

counter_X_pv(1,1)=1;
for j=2:size(pos_VI_x,2)
    if pos_VI_x(1,j) == pos_VI_x(1,j-1) && pos_VI_x(2,j) == pos_VI_x(2,j-1) && pos_VI_x(3,j) == pos_VI_x(3,j-1);
        counter_X_pv(1,j)=j-1;
    else counter_X_pv(1,j)=j;
    end
end
counter_X_pv(2,1)=1;
for j=2:size(meas_time_X);
    counter_X_pv(j,2)=j;
end

counter_x_new=[counter_X_pv;counter_X];

%%
plot(meas_time_X,pos_VI_x(1,:)*10,meas_time_X,acc_X(3,:));legend('pos','xacc')
%----------------------
%Building segments and running ekf
%----------------------
%% Building Segments
[segment1_Z_P,segment1_counter_P,segment1_time_P]=build_segment(35.723000000000000, 95.056000000000000, Z_p,counter_P_new,meas_time_P);
[segment1_Z_X,segment1_counter_X,segment1_time_X]=build_segment(35.723000000000000, 95.056000000000000, Z_x,counter_X_new,meas_time_X);

[segment2_Z_P,segment2_counter_P,segment2_time_P]=build_segment(95.056000000000000, 214.4140, Z_p,counter_P_new,meas_time_P);
[segment2_Z_X,segment2_counter_X,segment2_time_X]=build_segment(95.056000000000000, 214.4140, Z_x,counter_X_new,meas_time_X);

% [segment3_Z_P,segment3_counter_P,segment3_time_P]=build_segment(startTime, 214.4140, Z_p,counter_P,meas_time_P);
% [segment3_Z_X,segment3_counter_X,segment3_time_X]=build_segment(startTime, 214.4140, Z_x,counter_X,meas_time_X);
% 
% [segment4_Z_P,segment4_counter_P,segment4_time_P]=build_segment(345.4370, 450, Z_p,counter_P,meas_time_P);
% [segment4_Z_X,segment4_counter_X,segment4_time_X]=build_segment(345.4370, 450, Z_x,counter_X,meas_time_X);



%% Running the kalman filter function
[x_state,x_est]= state_estimation_3(Z,meas_time,counter);