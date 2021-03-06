function [R_dqp_12, R_dqp_3, R_xyz, S_0lab_dir] = plugin_NanoMAX(theta_bl, chi_bl, phi_bl, delta_bl, gamma_bl, rocking_increment, rocking_angle)
% convert reflection NanoMAX angles to a right-handed coordinate system for new reflection
% adapted by D.Dzhigaev 2020, Lund University
    theta = -phi_bl;
    chi = 90 - chi_bl;
    phi = -theta_bl;
    delta = -gamma_bl;
    gamma = delta_bl;

    % rotation matrices
    R_dqp_12 = rotyd(delta)*rotxd(gamma);
    R_xyz = rotyd(theta)*rotzd(chi)*rotxd(phi); % rotation matrix to rotate a vector in sample coordiantes into lab coordinates
    if strcmp(rocking_angle, 'dtheta')
        R_dqp_3 = rotyd(-rocking_increment); % it's the negative in rocking increment because we scan from negative to positive
    elseif strcmp(rocking_angle, 'dphi')
        R_dqp_3 = rotxd(-rocking_increment); % it's the negative in rocking increment because we scan from negative to positive
    end

    % X-ray beam incidence direction for NanoMAX: [x,y,z]
    S_0lab_dir = [0; 0; 1];
end