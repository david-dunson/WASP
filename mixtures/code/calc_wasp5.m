function calc_wasp5(dd, nsub, ndim)

if ndim == 1
    chr = 'mu1';
else 
    chr = 'mu2';
end

addpath('/opt/gurobi/6.5.1/linux64/matlab/');

margMat = {};
for kk = 1:nsub 
    margMat{kk} = csvread(strcat('/Shared/ssrivastva/wasp/mixtures/result/sub5/samp/csv/samp_cv_', ...
                                 num2str(dd), '_nsub_', num2str(kk), '_k5_', chr, '.csv'));
end
runtime = 0;

% calculate the pair-wise sq. euclidean distance between the atoms of subset
% posteriors and WASP atoms
subsetPost = {};    
for kk = 1:nsub
    subsetPost{kk} = margMat{kk}(randi([1 1000], 100, 1), :);
end         

lbd1 = min(cellfun(@(x) x(1), cellfun(@(x) min(x), subsetPost,'UniformOutput', false)));
lbd2 = min(cellfun(@(x) x(2), cellfun(@(x) min(x), subsetPost,'UniformOutput', false)));   
ubd1 = max(cellfun(@(x) x(1), cellfun(@(x) max(x), subsetPost,'UniformOutput', false)));
ubd2 = max(cellfun(@(x) x(2), cellfun(@(x) max(x), subsetPost,'UniformOutput', false)));   

[opostx, oposty] = meshgrid(linspace(lbd1, ubd1, 60), linspace(lbd2, ubd2, 60));
overallPost = [opostx(:) oposty(:)];

distMatCell = {};
m00 = diag(overallPost * overallPost');
for ii = 1:nsub
    mm = diag(subsetPost{ii} * subsetPost{ii}');    
    mm1 = overallPost * subsetPost{ii}'; 
    distMatCell{ii} = bsxfun(@plus, bsxfun(@plus, -2 * mm1, mm'), m00);    
end

% constants
K  = nsub;
Ni = cell2mat(cellfun(@(x) size(x, 2), distMatCell, 'UniformOutput', false));
N  = size(overallPost, 1);
nx = N * (N+1);
mx = K * N + N + 1;
In = eye(N);
En = ones(1, N);

% Generate matrix A0.
A0  = sparse([]);
for p = 1:K
    cc = (1:N)';                  % terribly fast version of 
    idx = cc(:, ones(Ni(p), 1));  % repmat(In, 1, Ni(p)) / Ni(p)
    Rp  = In(:, idx(:)) / Ni(p);  % in 3 steps
    A0  = blkdiag(A0, Rp); 
end
cc = (1:N)';                  % terribly fast version of 
idx = cc(:, ones(K, 1));      % repmat(-In, K, 1) 
A00  = -In(idx(:), :);        % in 3 steps

A0 = sparse([A00, A0]);
b0 = zeros(size(A0, 1), 1);
disp('done generating A ...');        

% Generate matrix B from simplex constraints.
B = sparse([]);
for p = 0:(sum(Ni))
    B = blkdiag(B, En);
end
disp('done generating B ...');        

% The hold matrix C.
A = sparse([A0; B]);

% Generate the right hand size vector b.
b = sparse([zeros(K * N, 1); ones(sum(Ni) + 1, 1)]);

% Generate the cost vector
costCell = cellfun(@(x) x(:) / size(x, 2), distMatCell, 'UniformOutput', false);
costVec = [zeros(size(overallPost, 1), 1); cell2mat(costCell(:))];

c = sparse(costVec);
tic;
lpsol = callLpSolver('gurobi', A, b, c, 10000, 1e-10);
runtime = toc;

[tmats, avec] = recoverSolution(lpsol, K, N, Ni);

save(strcat('/Shared/ssrivastva/wasp/mixtures/result/sub5/res_cv_', num2str(dd), ...
            '_', chr, '_k5.mat'), 'runtime', 'tmats','avec', 'subsetPost', 'overallPost');
summ = [overallPost avec];
csvwrite(strcat('/Shared/ssrivastva/wasp/mixtures/result/sub5/wasp_cv_', num2str(dd), ...
                '_', chr, '_k5.csv'), summ);
csvwrite(strcat('/Shared/ssrivastva/wasp/mixtures/result/sub5/overall_cv_', num2str(dd), ...
                '_', chr, '_k5.csv'), overallPost);
csvwrite(strcat('/Shared/ssrivastva/wasp/mixtures/result/sub5/time_cv_', num2str(dd), ...
                '_', chr, '_k5.csv'), runtime);    
quit
