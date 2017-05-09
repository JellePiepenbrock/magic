%% init
out_dir = '~/Google Drive/MAGIC Paper/Figures/paper_figs/EMT_network_analysis_kristi/';
mkdir(out_dir)
out_base = [out_dir 'may1_'];
addpath(genpath('~/Documents/MATLAB/cyt3-mac'))
addpath(genpath('~/Dropbox/DiffusionGeometry/'))
cd ~/git_projects/sparse-DREMI-project/
rseed = 7;
npca = 20;
addpath(genpath('~/Dropbox/EMT_dropseq/paper_figs/cbrewer/'))
addpath(genpath('~/git_projects/sparse-DREMI-project/bhtsne-master/'));
num_bin = 20;
num_grid = 60;
k_dremi = 10;
addpath(genpath('~/git_projects/ParTi/'));
addpath(genpath('~/git_projects/PHATE/'));
cmp_red = cbrewer('seq', 'OrRd', 1000);

%% load data
data_TGFb = load('~/Dropbox/EMT_dropseq/Data/HMLE/sdata_norm_TGFb_day_8_10.mat');
sdata_TGFb = data_TGFb.sdata;

%% filter TGFb
genes_keep = find(sdata_TGFb.cpg >= 5);
sdata_filt_TGFb = sdata_TGFb;
sdata_filt_TGFb.data = sdata_filt_TGFb.data(:,genes_keep);
sdata_filt_TGFb.genes = sdata_filt_TGFb.genes(genes_keep);
sdata_filt_TGFb.mpg = sdata_filt_TGFb.mpg(genes_keep);
sdata_filt_TGFb.cpg = sdata_filt_TGFb.cpg(genes_keep);
sdata_filt_TGFb = sdata_filt_TGFb.recompute_name_channel_map()

%% MAGIC
ka = 10;
k = 30;
epsilon = 1;
t = 6;
rng(rseed);
[~, ~, ~, sdata_imputed_TGFb, ~, ~, ~] = MAGIC_impute(sdata_filt_TGFb, 'kernel', 'gaussian', 'k', k, ...
    'npca', npca, 't', t, 'rescale', 'max', 'rescale_to', 99, 'ka', ka, 'epsilon', epsilon, 'n_eig', 0);

%% filter dead cells TGFb
x = get_channel_data(sdata_imputed_TGFb, 'Mt-nd1');
ind_cells_keep = x < 6;
sum(~ind_cells_keep)
sdata_imputed_TGFb.data = sdata_imputed_TGFb.data(ind_cells_keep,:);
sdata_imputed_TGFb.cells = sdata_imputed_TGFb.cells(ind_cells_keep);
sdata_imputed_TGFb.library_size = sdata_imputed_TGFb.library_size(ind_cells_keep);

%% load DREMI
load('~/Downloads/TF_predictions.mat')

%% construct graph and get centrality scores
[genes_dremi,IA,IB] = intersect(x_genes, y_genes);
M_knn = prediction_matrix(IA,IB);
G = digraph(M_knn);
Gu = graph(M_knn + M_knn' > 0);
centr.pg_ranks = centrality(G,'pagerank');
centr.btw = centrality(G,'betweenness');
centr.hb = centrality(G,'hubs');
centr.auth = centrality(G,'authorities');
centr.ev = centrality(Gu,'eigenvector');

%% dremi matrix subset
M = dremi_matrix(IA,IB);

%% Louvain on kNN
C_ph = phenograph([], 0, 'G', M_knn);
tabulate(C_ph)

%% top page ranks
[~,sind] = sort(centr.pg_ranks, 'descend');
sort(genes_dremi(sind(1:100)))

%% write pagerank score to file
T = table();
N = 100;
[sscores,sind] = sort(centr.ev, 'descend');
T.gene = genes_dremi(sind(1:N));
T.ev = sscores(1:N) ./ max(sscores);
writetable(T, [out_base 'ev_scores_top100.txt'], 'Delimiter', '\t');

%% distributions of Pagerank score
score_vec = centr.auth;
%score_vec = log(score_vec);
genes_EMT = read_gene_set('~/Dropbox/EMT_dropseq/gene_lists/EMT_final.txt');
[C,IA,IB] = intersect(genes_dremi, genes_EMT);
IA_log = false(size(score_vec));
IA_log(IA) = 1;
[f1,xi1] = ksdensity(score_vec(~IA_log));
[f2,xi2] = ksdensity(score_vec(IA_log));
figure;
hold on;
plot(xi1, f1, '-r', 'linewidth', 2, 'displayname', 'non EMT genes');
plot(xi2, f2, '-b', 'linewidth', 2, 'displayname', 'EMT genes');
legend('location', 'NE')
xlabel 'authority score'
set(gcf,'paperposition',[0 0 4 3]);
print('-dtiff',[out_base '_auth_distro_emt.tiff']);
close

%% plot top 100 network
N = 100;
[~,sind] = sort(centr.pg_ranks, 'descend');
ind_sub = sind(1:N);
G1_sub = digraph(M_knn(ind_sub,ind_sub), 'OmitSelfLoops');
figure;
plot(G1_sub, 'Layout', 'force', 'NodeLabel', genes_dremi(ind_sub), ...
    'ArrowSize', 0, 'NodeCData', log(centr.pg_ranks(ind_sub)), 'MarkerSize', 10);
axis tight
h = colorbar;
set(h,'ytick',[]);
ylabel(h,'eigenvector centrality');
title(['top ' num2str(N) ' eigenvector centrality']);
set(gca,'xtick',[]);
set(gca,'ytick',[]);
set(gcf,'paperposition',[0 0 8 6]);
print('-dtiff',[out_base '_graph_layout_top_pg_ranks' num2str(N) '.tiff']);
close

%% plot top 100 network, colored by peak
M = sdata_imputed_TGFb.data;
[~,IA,IB] = intersect(genes_dremi, sdata_imputed_TGFb.genes);
M = M(:,IB);
traj = get_channel_data(sdata_imputed_TGFb, 'VIM');
[~,ind_cells] = sort(traj, 'ascend');
M = M(ind_cells, :);
[~,~,traj_max,~] = find_peak(M, 'S', 20);
N = 100;
[~,sind] = sort(centr.ev, 'descend');
ind_sub = sind(1:N);
G1_sub = digraph(M_knn(ind_sub,ind_sub), 'OmitSelfLoops');
figure;
plot(G1_sub, 'Layout', 'force', 'NodeLabel', genes_dremi(ind_sub), ...
    'ArrowSize', 0, 'NodeCData', traj_max(ind_sub), 'MarkerSize', 10);
axis tight
h = colorbar;
set(h,'ytick',[]);
ylabel(h,'peak time');
title(['top ' num2str(N) ' Pagerank']);
set(gca,'xtick',[]);
set(gca,'ytick',[]);
set(gcf,'paperposition',[0 0 8 6]);
print('-dtiff',[out_base '_graph_layout_top_' num2str(N) '_ev_colored_by_peak_time.tiff']);
close

%% timing versus centrlity
M = sdata_imputed_TGFb.data;
[~,IA,IB] = intersect(genes_dremi, sdata_imputed_TGFb.genes);
M = M(:,IB);
traj = get_channel_data(sdata_imputed_TGFb, 'VIM');
[~,ind_cells] = sort(traj, 'ascend');
M = M(ind_cells, :);
[~,~,traj_max,ind_genes] = find_peak(M, 'S', 20);
figure;
hold all;
x = traj_max;
y = (centr.ev);
[x,sind] = sort(x);
y = y(sind);
scatter(x, y, 10, 'filled');
plot(x, smooth(x, y, 200, 'sgolay'), '-r', 'linewidth', 2);
xlabel 'peak time'
ylabel 'log Pagerank score'
axis tight;
set(gcf,'paperposition',[0 0 8 6]);
print('-dtiff',[out_base '_peak_vs_ev_scatter_smooth.tiff']);
%close

%% plot top 100 network, colored by phenograph
N = 100;
[~,sind] = sort(centr.ev, 'descend');
ind_sub = sind(1:N);
G1_sub = digraph(M_knn(ind_sub,ind_sub), 'OmitSelfLoops');
figure;
plot(G1_sub, 'Layout', 'force', 'NodeLabel', genes_dremi(ind_sub), ...
    'ArrowSize', 0, 'NodeCData', C_ph(ind_sub), 'MarkerSize', 10);
axis tight
colormap(hsv);
title(['top ' num2str(N) ' eigenvector centrality']);
set(gca,'xtick',[]);
set(gca,'ytick',[]);
set(gcf,'paperposition',[0 0 8 6]);
print('-dtiff',[out_base '_graph_layout_top' num2str(N) '_ev_colored_by_phenograph.tiff']);
close

%% plot top 100 network, colored by phenograph
N = 100;
[~,sind] = sort(centr.ev, 'descend');
ind_sub = sind(1:N);
G1_sub = digraph(M_knn(ind_sub,ind_sub), 'OmitSelfLoops');
figure;
plot(G1_sub, 'Layout', 'force', 'NodeLabel', genes_dremi(ind_sub), ...
    'ArrowSize', 0, 'NodeCData', C_ph(ind_sub), 'MarkerSize', 10);
axis tight
colormap(hsv);
title(['top ' num2str(N) ' eigenvector centrality, colored by Phenograph']);
set(gca,'xtick',[]);
set(gca,'ytick',[]);
set(gcf,'paperposition',[0 0 8 6]);
print('-dtiff',[out_base '_graph_layout_top' num2str(N) '_ev_colored_by_phenograph.tiff']);
close

%% tSNE
npca = 10;
tsne_knn = fast_tsne(svdpca(M,npca,'random'), 2, npca, 30, 0.5);

%% plot tSNE, colored by phenograph
C = C_ph + 1;
gene_set = genes_dremi;
genes_hl = {'Zeb1' 'Snai1' 'Snai2' 'Twist1' 'Zeb2' 'Myc' 'Trim28' 'Ezh2' 'Klf8' 'Tcf4' 'Six1' 'Foxc2' 'GRHL2' ...
    'Elf3' 'Elf3' 'Tp53' 'Yap1' 'Tead1' 'CTBP' 'Dkk1' 'Smad4' 'Klf5'};
[~,sind] = sort(C, 'descend');
%genes_hl = [genes_dremi(sind(1:20)); genes_hl'];
%genes_hl = [genes_dremi(sind(1:100))];
clr = hsv(length(unique(C)));
figure;
scatter(tsne_knn(:,1), tsne_knn(:,2), 0, C, 'filled');
axis tight
hold on
for I=1:size(tsne_knn,1)
    I
    if ismember(lower(gene_set{I}), lower(genes_hl))
        h = text(tsne_knn(I,1), tsne_knn(I,2), gene_set{I}, 'fontsize', 16, 'color', clr(C(I),:));
        %h = text(pc_knn(I,1), pc_knn(I,2), gene_set{I}, 'fontsize', 16, 'color', clr(I,:));
        set(h, 'FontWeight', 'bold');
    else
        text(tsne_knn(I,1), tsne_knn(I,2), gene_set{I}, 'fontsize', 8, 'color', clr(C(I),:));
    end
end
set(gca,'xtick',[]);
set(gca,'ytick',[]);
title('EMT genes highlighted');
set(gcf,'paperposition',[0 0 16 12]);
print('-dtiff',[out_base '_tSNE_phenograph.tiff']);
close

%% write genes per cluster
for I=1:max(C_ph)
    T = table();
    T.gene = genes_dremi(C_ph==I);
    T.ev_score = centr.ev(C_ph==I);
    [~,sind] = sort(T.ev_score,'descend');
    T.gene = T.gene(sind);
    T.ev_score = T.ev_score(sind);
    writetable(T, [out_base 'C_phenograph_' num2str(I) '.txt'], 'Delimiter', '\t');
end
