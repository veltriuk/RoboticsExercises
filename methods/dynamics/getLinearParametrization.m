function Y = getLinearParametrization(u,a)
% $Author: Andr�s Arciniegas $  $Date: 2019/06/13 $ $Revision: 0.1 $

% Computes linear parametrization grouping, provided the dynamic
% coefficients

% Parameters:
% Msubs: Inertia matrix M, with substitution by dynamic coefficients (getDynamicParameters.m)
% qdd: Vector of accelerations. Example: [qdd1,qdd2...,qddn]
% Cs: Christoffel's symbols
% a: Dynamic coefficients vector. Example: [a1,a2,a3]
%
% Returns: Y matrix

% See also: getDynamicParameters, getKEwithJacobian, getInertiaMatrixFromKE

% if ~exist('Cs','var')
%      % Default parameters
%     Cs = 0;
% end   

%u = Msubs*qdd + Cs

Yu = collect(u,a);
Y = [];
for i = 1:length(a)
    % Isolate the 'a' coefficient by taking the derivative
    Y = [Y, diff(Yu,a(i))];
end

end
