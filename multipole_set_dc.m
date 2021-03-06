function el = multipole_set_dc(trap,E,U,A,multipoleControls,regularize)
% function el = multipole_set_dc(trap,Ex,Ey,Ez,U1,U2,U3,U4,U5,ax,az,phi,multipoleControls,regularize)
% Set the dc voltages gor all dc electrodes using the trap multipoles.
% E,U and E,A are alternative input control combinations. 
% trap is the usual trap structure
% Ex,Ey,Ez is the field generated by the trap at the ion position
% U1-U5 are the five multipoles (or five 0s if no independent input is set)
% A4 = [ax, az, theta]
% ax and az are the alpha parameters in the frame aligned with the dc quadrupole 
% phi is the rotation of the dc quadrupole wrt the rf quadrupole in degrees, 
% multipoleControls is a boolean control that sets the control parameters to be the U's 
% (true), or the alpha parameters. 
% regularize is a second boolean control determining whether the 
% output is to be regularized or not (by regularization I mean minimizing 
% the norm of el with addition of vectors belonging to the kernel of 
% trap.Configuration.multipoleCoefficients)
%
%                           ( multipoles    electrodes ->       )
%                           (     |                             )
% multipoleCoefficients =   (     V                             )
%                           (                                   )
%
%                           ( electrodes    multipoles ->       )
%                           (     |                             )
% multipoleControl =        (     V                             )
%                           (                                   )
%
% Nikos, July 2009
% Cleaned up October 2013

if size(E,1)<size(E,2),
    E = E';
end

if multipoleControls
    %inp = [Ex Ey Ez U1 U2 U3 U4 U5]';
    if size(U,1)< size(U,2),
        U = U';
    end
    M = vertcat(E,U);
    el = trap.Configuration.multipoleControl*M;				% these are the electrode voltages
else   
    ax = A3(1);
    az = A3(2);
    phi = A3(3);
    rf_frequency = trap.Instance.driveFrequency;
    charge = trap.Configuration.charge;
    mass = trap.Configuration.mass;
    r0 = trap.Configuration.r0;						% length scale of multipole expansion in millimeters
    V0 = mass*(2*pi*rf_frequency)^2*(r0*1e-3)^2/charge;                        	% god given voltage in SI
    U2 = az*V0/8;
    %U1p = U2+ax*V0/4;
    %U1 = U1p*cos(2*pi*(phi+trap.thetarf)/180);
    %U3 = 2*U1p*sin(2*pi*(phi+trap.thetarf)/180);
    U1 = U2+ax*V0/4;
    U3 = 2*U1*tan(2*pi*(phi+trap.Configuration.thetarf)/180);
    U1p= sqrt(U1^2+U3^2/2);
    U4 = U1p*trap.Configuration.Qrf(4)/trap.Configuration.Qrf(1);
    U5 = U1p*trap.Configuration.Qrf(5)/trap.Configuration.Qrf(1);
    Multipoles = vertcat(E,[U1 U2 U3 U4 U5]');
    el = trap.Configuration.multipoleControl*Multipoles;				% these are the electrode voltages
end

if regularize
    c = el;
    lmbda = trap.Configuration.multipoleKernel\c;
    el = el-(trap.Configuration.multipoleKernel*lmbda);
end
    
