% free mass model

t=0.01; % [s] time interval between two measurements
G= [0;0;9.85]; % [m/s^2] gravitation in zurich
dis=[0;0;0];%displacementvector of the box
MAG1=0.2145;% [Gauss] magnetic field in zurich
MAG2=0.0060;
MAG3=0.4268;
true_mag=[-0.119784172661871;-0.0330935251798561;0.341007194244604;];
mag_angle=-1.496;
mag=[cos(mag_angle),sin(mag_angle),0;-sin(mag_angle),cos(mag_angle),0;0,0,1]*true_mag;
%Rl= geocradius(47+24/60); %from zurich
%Rp= Rl*cos(8+32/60); %from zurich
lat0=47+24/60;
long0=8+32/60;
% noise form Xsens datasheet


NOISE_ACC_b=10*[0.14;0.14;0.14];% [m/s^2/sqrt(Hz)]noise acc   Xsens: [0.002;0.002;0.002]
NOISE_GYRO_b=[0.3;0.3;0.3]*2*pi/360;% [rad/s] noise gyro      Xsens: [0.05;0.05;0.05]./360.*2*pi
NOISE_MAG_b=1000*[0.002;0.002;0.002];%[gauss]                         Xsens: [0.5e-3;0.5e-3;0.5e-3]

NOISE_GPS_POS=0.0005;% Noise in position of the GPS
NOISE_GPS_VEL=0.005;%Noise in velocity of the GPS


%------------------------
% variables with initial values are defined
%------------------------
% x = [-0.08372,-0.2276,-0.8123,-0.5,-0.2,0,0,-0.2901,-1.9233, 0, 0.0171, -2.2197,0,0,0,0,0,0,0,0,0]';
% P = zeros(size(x,1),size(x,1));
% quat = [0,0,1,0]';
x = [0.451525,-0.02503,-0.7155918,...
    -0.1635,-0.7756,-0.0852,...
    0,-0.563581455457894, -0.0553776831161063,...
    0,0.173924051749699,-1.73248360301804,...
    0,0,0,0,0,0,0,0,0]';
P = zeros(size(x,1),size(x,1));
%------------------------
% Q and R are calculated
%------------------------
%  q_diag=[0.001,0.001,0.001,0.01,0.01,0.01,0.0001,0.0001,0.0001,0.0001,0.0001,0.0001,0,0,0,0,0,0,0,0,0];
%     
%     Q=diag(q_diag);
% 
% 
% r=[NOISE_GPS_POS,NOISE_GPS_POS,NOISE_GPS_POS,NOISE_GPS_VEL,NOISE_GPS_VEL,NOISE_GPS_VEL,(NOISE_ACC_b.^2)',(NOISE_GYRO_b.^2)',(NOISE_MAG_b.^2)'];
% R=diag(r);

% noise predection
q_diag=[0.001,0.001,0.001,0.01,0.01,0.01,0.0001,0.0001,0.0001,0.01,0.01,0.01,0,0,0,0,0,0,0,0,0];
Q=diag(q_diag);

% noise correction
r=[NOISE_GPS_POS,NOISE_GPS_POS,NOISE_GPS_POS,NOISE_GPS_VEL,NOISE_GPS_VEL,NOISE_GPS_VEL,(NOISE_ACC_b)',(NOISE_GYRO_b)',(NOISE_MAG_b)'];
R=diag(r);



%%
%------------------------
% for every measurement the Extended Kalman Filter is used for state
% estimation
%------------------------
i=10000;
totalTime=meas_time(i);

k=1;
while (i<size(M,2))%size(M,2)
    totalTime=totalTime+t
    %------------------------
    % direct cosine matrice gets calculated
    %------------------------

    DCM_bi=calc_DCM_br(x(7),x(8),x(9));
    
%     
%     %noise, dependent on DCMs
%     NOISE_ACC_i=(NOISE_ACC_b);%DCM_ir*
%     NOISE_VEL_i=[NOISE_GPS_VEL;NOISE_GPS_VEL;NOISE_GPS_VEL];
%     NOISE_POS_i=(NOISE_VEL_i.^2)*t;
%     NOISE_GYRO_i=(NOISE_GYRO_b);%DCM_ir*
%     NOISE_CARTAN_i=(NOISE_GYRO_i.^2)*t;
    
    %q_diag=[NOISE_POS_i',NOISE_VEL_i',NOISE_CARTAN_i', NOISE_GYRO_i',0,0,0,0,0,0,0,0,0].*noise_scale;
   
    
    
    [x_est,A]=jaccsd_free_mass_model(@free_mass_model,x,t);
    
    %estimation step
    P_est=A*P*A'+Q;
    
    % there is no new sensor value. the ekf is just propagating
    if(meas_time(i+1)>totalTime)
        disp('no new value within t')
        x_new=x_est;
        P=P_est;
        [z_est,H]=jaccsd_h_euler(@h_euler,x_est,x,t,dis,G,mag);
        
    else
    
    
    %correction step
    
%     DCM_br_est=calc_DCM_br(x_est(7),x_est(8),x_est(9));
%     DCM_bi_est=DCM_br_est*DCM_ir';
   
    [z_est,H]=jaccsd_h_euler(@h_euler,x_est,x,t,dis,G,mag);
    
    
    
    
    if(i==1)
        i_old=10;
    else
        i_old =i-1;
    end
    
    while(meas_time(i+1)<=totalTime) %looking for the closest measurement value to the estimatin time "totalTime"
        i=i+1;
    end
    
    z_new=M(:,i);
    counter_new=counter(:,i);
    counter_old=counter(:,i_old);
    length_z=size(z_new);
    
    
    meas_control= d_meas(counter_new,counter_old,length_z);
    
    x_tmp=x_est;
    P_tmp=P_est;
    for j=1:size(meas_control,2)                  % only for the measurements from which we have new sensor data, the correction step is done
        if meas_control(j)==1
%             [x_tmp,P_tmp]= correction(P_tmp,H(j,:),R(j,j),z_new(j),x_tmp,j);
              P12=P_tmp*H(j,:)';                   %cross covariance
              % K=P12*inv(H*P12+R);       %Kalman filter gain
              % x=x1+K*(z-z1);            %state estimate
              % P=P-K*P12';               %state covariance matrix
              [S,p]=chol(H(j,:)*P12+R(j,j));  %Cholesky factorization
               
              if p~=0
                    disp('not positive definite') % this is required for the argument of chol(...), otherwise the filter is unstable
                    i
                    j
                end
%               if p~=0
%                    K=P12*inv(H(j,:)*P12+R(j,j));       
%                    x_tmp=x_tmp+K*(z_new(j)-z_est(j));            
%                    P_tmp=P_tmp-K*P12';
             % else
                   U=P12/S;                    %K=U/R'; Faster because of back substitution
                   x_tmp=x_tmp+U*(S'\(z_new(j)-z_est(j)));         %Back substitution to get state update
                   P_tmp=P_tmp-U*U';
            %  end
            
        end
            
    end
    x_new=x_tmp;
    P=P_tmp;
    end
    
%     %saving:
%     save_time(k)=totalTime;
%     if k>1
%         save_x(:,k-1)=x;
%         save_x(:,k)=0;
%     end
% %    save_x(:,k)=x;
%     save_new(:,k)=x_new;
%     save_est(:,k)=x_est;
    
    
     %saving:
    save_deviation(:,k)=(z_est-z_new)./z_new;
    save(:,k)=x;
    save_est(:,k)=x_est;
    save_corr(:,k)=x_new;
    save_t(k)=totalTime;
    save_z_est(:,k)=z_est;
    save_z(:,k)=z_new;
    [val,ind]=min(abs(meas_time_P-meas_time(i)));
    save_anlges(:,k)=angles_VI_p(:,ind);
    
    
    k=k+1;
    
    x=x_new;
  
    
end


%%
% %plot(save_t,save(1:3,:),save_t,save_est(1:3,:),meas_time,M(1:3,:))
% figure(1);plot(save_time,save_x(1:3,:),'o-',save_time,save_est(1:3,:),'.',save_time,save_new(1:3,:),'x-');
% figure(2);plot(save_time,save_x(4:6,:),'o-',save_time,save_est(4:6,:),'.',save_time,save_new(4:6,:),'x-');
% %figure(3);plot(save_time,save_x(7:9,:),'o-',save_time,save_est(7:9,:),'.',save_time,save_new(7:9,:),'x-');
% figure(3);plot(save_time,save_quat,'.-');
% figure(4);plot(save_time,save_x(10:12,:),'o-',save_time,save_est(10:12,:),'.',save_time,save_new(10:12,:),'x-');
% 

%% pos and vel compared to ground truth
figure(5);plot(save_t,save_x(1,:),save_t,save_new(1,:),save_t,save_est(1,:),segment1_time_ground_truth,segment1_ground_truth(1,:),save_time,save_x(4,:)/10,save_time,save_new(4,:)/10,segment1_time_ground_truth,segment1_ground_truth(4,:)/10);legend('x','new','est','ground truth','v state x','v est x','v ground truth')
%% psi
figure(6);plot(save_t,-mod(save_est(9,:),2*pi)+pi,segment1_time_ground_truth, segment1_ground_truth(7,:));legend('euler x','euler gt')
%% thet
figure(7);plot(save_t,save_est(7,:),segment1_time_ground_truth, segment1_ground_truth(9,:));legend('euler x','euler gt')
%% phi
figure(8);plot(save_t,-save_est(8,:),save_t,-save_corr(8,:),segment1_time_ground_truth, segment1_ground_truth(9,:));legend('est','new','euler gt')


%%
figure(1);plot(save_t,save_z_est(1:3,:),'o-',save_t,save_z(1:3,:),'.');
figure(2);plot(save_t,save_z_est(4:6,:),'o-',save_t,save_z(4:6,:),'.');
figure(3);plot(save_t,save_z_est(7:9,:),'o-',save_t,save_z(7:9,:),'.');
figure(4);plot(save_t,save_z_est(10:12,:),'o-',save_t,save_z(10:12,:),'.');
figure(5);plot(save_t,save_z_est(13:15,:),'o-',save_t,save_z(13:15,:),'.');
figure(6);plot(save_t,save(7:9,:),'o-',save_t,save_anlges(1:3,:),'.');

%%
figure(9);plot(save_t,save_deviation(7,:))
