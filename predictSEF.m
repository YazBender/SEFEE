function [Tp,Tdec] = predictSEF(Z,obsA,obsB,s,R,e)
%predictSEF, recieves observed tensor and returns the next prediction and
%the factorized observed tensor.
%   Tp is the predicted tensor slice and is of size I X J X 1 since we only predict one step into the future
%   for now. But the code can be changed to accomodate more predictions per
%   step by modifying htodOuterProduct to compute further back. I have not
%   included this modification in this version of the code. For now, it is
%   possible to just change the granularity of the data (time-bin) and
%   predict.
customOptions =0;

if s == 0 %this means s was passed as a flag
    htod = 0;
else       % means s is a matrix and that is time of day matrix
    htod = 1;
end

id = 'MATLAB:nearlySingularMatrix'; %This type of warning happens very often. Since our data was extremely sparse the tensor would become ill-conditioned
% resulting in such errors in time-steps that were all missing.
warning('off',id);
%------------parameters----------------------
TW = 3; %Time window, how many previous time steps shall be considered to predict the future
if nargin <6
 e =12; % time-specific effect e.g. if our data is Day-binned and e is set to 7 it triggers day of the week effect.
end
if isstruct(Z)
    D = Z.object{1};
    % Must check if Z has Weight field (Z.miss) and if so store it
    % somewhere so We could match it with the same range of D.
    if isfield(Z,'miss')
        W = Z.miss{1};
    end
else
    D = Z;
end

obsT= D(:,:,obsA:obsB); %observed tensor from original data
if isfield(Z,'miss')
    wT = W(:,:,obsA:obsB);
end
obsT = tensor(obsT); %changing the double 3D array to tensor data type from tensor_toolbox, so it could be passed to CP functions in tensor_toolbox

obsSize = size(obsT);
if R==0 %setting R equal to a loose upper bound limit. this value is usually too high and it will result in overfactoring and poor results.
    %   so it is best to set R manually.
    R = min([obsSize(1)*obsSize(2) obsSize(1)*obsSize(3) obsSize(2)*obsSize(3)]); 
end
fprintf('Dimension of observed tensor is: %d , %d, %d. Using Rank R= %d for decomposition \n', obsSize, R);

fprintf('Predicting(estimating) values at time %d \n', obsB+1);
fprintf('\n\n');

if isstruct(Z)
    Z.object{1} = obsT;
    Z.size = unique([size(Z.object{1}) size(Z.object{2})],'stable'); % fixing the size variable based on Z objects.
    if isfield(Z,'miss')
        Z.miss{1} = tensor(wT);
        Z.miss{2} = tensor(Z.miss{2});
    end
    if customOptions
        options = ncg('defaults');
        options.MaxFuncEvals = 13000;
        options.MaxIters = 1300;
        %options.StopTol = 1e-8;
        %options.RelFuncTol = 1e-8;
        obsTdec = cmtf_opt(Z,R,'alg','ncg','alg_options',options); %obsTdec is observed Tensor decomposed into factor matrices.
    else
    obsTdec = cmtf_opt(Z,R); %all default options.
    end
else
    if customOptions
        obsTdec = cp_als(obsT,R,'maxiters',100); 
    else
        obsTdec = cp_als(obsT,R); % decomposing/factorising the observed tensor with RANK = min(IJ,IK,JK) where I,J,K are modes of the observed set
    end
end
A = obsTdec{1}; B = obsTdec{2}; C= obsTdec{3}; %factor matrices A , B & C
lambda = obsTdec.lambda;



if htod
    Tpred = htodOuterProduct(obsTdec,transpose(s));
else % if htod is 0 then the time factor will be computed simply by averaging over the last 3 time slices according to e, and then the predicted tensor is calcualted using regular outer product.
    g = modifyTemporalFac(C,TW,e);  % modified temporal factor   %TW default = 3 and e default is 1
    Tpred = outp(A,B,g,lambda); % use A and B from the factorized observed tensor obsTdec + g(e.g. TW = 3 should return the average of the last 3 Ck from C factor matrix)
end

% if isfield(Z,'miss')
%     Tpred = Tpred .* W;
%TpredR = round(Tpred);
Tp = Tpred;

Tdec = obsTdec;

warning('on',id);
end
