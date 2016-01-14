clear all
close all hidden
clc

%% Parameters
query = "R2_two_cols";
base_dir = "/home/eugenio/Desktop/cineca-runs-20150111/";

C_range = linspace (0.1, 5, 20);
E_range = linspace (0.1, 5, 20);

%% Real stuff
[values, sample] = read_from_directory ([base_dir, query, "/small"]);
[big_values, big_sample] = read_from_directory ([base_dir, query, "/big"]);

dimensions = size (sample, 2);

sample_nCores = sample;
sample_nCores(:, end) = 1 ./ sample_nCores(:, end);

big_sample_nCores = big_sample;
big_sample_nCores(:, end) = 1 ./ big_sample_nCores(:, end);

big_size = max (big_sample(:, end - 1));
everything = [values, sample; big_values, big_sample];
everything = clear_outliers (everything);
idx_small = (everything(:, end - 1) < big_size);
idx_big = (everything(:, end - 1) == big_size);
[everything, ~, ~] = scale (everything);
y = everything(idx_small, 1);
X = everything(idx_small, 2:end);
big_y = everything(idx_big, 1);
big_X = everything(idx_big, 2:end);

big_size = max (big_sample_nCores(:, end - 1));
everything = [values, sample_nCores; big_values, big_sample_nCores];
everything = clear_outliers (everything);
idx_small = (everything(:, end - 1) < big_size);
idx_big = (everything(:, end - 1) == big_size);
[everything, ~, ~] = scale (everything);
y_nCores = everything(idx_small, 1);
X_nCores = everything(idx_small, 2:end);
big_y_nCores = everything(idx_big, 1);
big_X_nCores = everything(idx_big, 2:end);

test_frac = 0.6;
train_frac = 0.2;

[ytr, Xtr, ytst, Xtst, ycv, Xcv] = ...
  split_sample ([y; big_y], [X; big_X], train_frac, test_frac);
[ytr_nCores, Xtr_nCores, ytst_nCores, Xtst_nCores, ycv_nCores, Xcv_nCores] = ...
  split_sample ([y_nCores; big_y_nCores], [X_nCores; big_X_nCores], train_frac, test_frac);

RMSEs = zeros (1, 4);
Cs = zeros (1, 4);
Es = zeros (1, 4);
predictions = zeros (numel (ycv), 4);
w = cell (1, 2);
b = cell (1, 2);

%% White box model, nCores
[C, eps] = model_selection (ytr, Xtr, ytst, Xtst, "-s 3 -t 0 -q -h 0", C_range, E_range);
options = ["-s 3 -t 0 -h 0 -p ", num2str(eps), " -c ", num2str(C)];
model = svmtrain (ytr, Xtr, options);
[predictions(:, 1), accuracy, ~] = svmpredict (ycv, Xcv, model);
Cs(1) = C;
Es(1) = eps;
RMSEs(1) = sqrt (accuracy(2));
w{1} = model.SVs' * model.sv_coef;
b{1} = - model.rho;

%% White box model, nCores^(-1)
[C, eps] = model_selection (ytr_nCores, Xtr_nCores, ytst_nCores, Xtst_nCores, "-s 3 -t 0 -q -h 0", C_range, E_range);
options = ["-s 3 -t 0 -h 0 -p ", num2str(eps), " -c ", num2str(C)];
model = svmtrain (ytr_nCores, Xtr_nCores, options);
[predictions(:, 2), accuracy, ~] = svmpredict (ycv_nCores, Xcv_nCores, model);
Cs(2) = C;
Es(2) = eps;
RMSEs(2) = sqrt (accuracy(2));
w{2} = model.SVs' * model.sv_coef;
b{2} = - model.rho;

%% Black box model, Polynomial
[C, eps] = model_selection (ytr, Xtr, ytst, Xtst, "-s 3 -t 1 -q -h 0", C_range, E_range);
options = ["-s 3 -t 1 -h 0 -p ", num2str(eps), " -c ", num2str(C)];
model = svmtrain (ytr, Xtr, options);
[predictions(:, 3), accuracy, ~] = svmpredict (ycv, Xcv, model);
Cs(3) = C;
Es(3) = eps;
RMSEs(3) = sqrt (accuracy(2));

%% Black box model, RBF
[C, eps] = model_selection (ytr, Xtr, ytst, Xtst, "-s 3 -t 2 -q -h 0", C_range, E_range);
options = ["-s 3 -t 2 -h 0 -p ", num2str(eps), " -c ", num2str(C)];
model = svmtrain (ytr, Xtr, options);
[predictions(:, 4), accuracy, ~] = svmpredict (ycv, Xcv, model);
Cs(4) = C;
Es(4) = eps;
RMSEs(4) = sqrt (accuracy(2));

robust_avg_value = median (ycv);

percent_RMSEs = 100 * RMSEs / max (RMSEs);
rel_RMSEs = RMSEs / abs (robust_avg_value);

abs_err = abs (predictions - ycv);
rel_err = abs_err ./ abs (ycv);

max_rel_err = max (rel_err);
min_rel_err = min (rel_err);
mean_rel_err = mean (rel_err);

max_abs_err = max (abs_err);
mean_abs_err = mean (abs_err);
min_abs_err = min (abs_err);

mean_y = mean (ycv);
mean_predictions = mean (predictions);
err_mean = mean_predictions - mean_y;
rel_err_mean = abs (err_mean / mean_y);

%% Plots
switch (dimensions)
  case {1}
    figure;
    plot (X, y, "g+");
    hold on;
    plot (big_X, big_y, "bd");
    plot (Xcv, ycv, "rx");
    func = @(x) w{1} .* x + b{1};
    extremes = xlim ();
    x = linspace (extremes(1), extremes(2), 10);
    plot (x, func (x), "r-");
    axis auto;
    title ("Linear kernels");
    grid on;
    
    figure;
    plot (X_nCores, y_nCores, "g+");
    hold on;
    plot (big_X_nCores, big_y_nCores, "bd");
    plot (Xcv_nCores, ycv_nCores, "rx");
    func = @(x) w{2} .* x + b{2};
    extremes = xlim ();
    x = linspace (extremes(1), extremes(2), 10);
    plot (x, func (x), "r-");
    axis auto;
    title ('Linear kernels, nCores^{- 1}');
    grid on;
  case {2}
    figure;
    plot3 (X(:, 1), X(:, 2), y, "g+");
    hold on;
    plot3 (big_X(:, 1), big_X(:, 2), big_y, "bd");
    plot3 (Xcv(:, 1), Xcv(:, 2), ycv, "rx");
    func = @(x, y) w{1}(1) .* x + w{1}(2) .* y + b{1};
    extremes = xlim ();
    x = linspace (extremes(1), extremes(2), 10);
    extremes = xlim ();
    x = linspace (extremes(1), extremes(2), 10);
    extremes = ylim ();
    yy = linspace (extremes(1), extremes(2), 10);
    [XX, YY] = meshgrid (x, yy);
    surf (XX, YY, func (XX, YY));
    axis auto;
    title ("Linear kernels");
    grid on;
    
    figure;
    plot3 (X_nCores(:, 1), X_nCores(:, 2), y_nCores, "g+");
    hold on;
    plot3 (big_X_nCores(:, 1), big_X_nCores(:, 2), big_y_nCores, "bd");
    plot3 (Xcv_nCores(:, 1), Xcv_nCores(:, 2), ycv_nCores, "rx");
    func = @(x, y) w{2}(1) .* x + w{2}(2) .* y + b{2};
    extremes = xlim ();
    x = linspace (extremes(1), extremes(2), 10);
    extremes = ylim ();
    yy = linspace (extremes(1), extremes(2), 10);
    [XX, YY] = meshgrid (x, yy);
    surf (XX, YY, func (XX, YY));
    axis auto;
    title ('Linear kernels, nCores^{- 1}');
    grid on;
endswitch

%% Print metrics
display ("Root Mean Square Errors");
RMSEs
percent_RMSEs
rel_RMSEs

display ("Relative errors (absolute values)");
max_rel_err
mean_rel_err
min_rel_err

display ("Absolute errors (absolute values)");
max_abs_err
mean_abs_err
min_abs_err

display ("Relative error between mean measure and mean prediction (absolute value)");
rel_err_mean
