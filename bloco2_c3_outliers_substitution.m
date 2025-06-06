%
% Bloco 2 - Scripts de Processamento LabOceano
%
% Passo 3: Detecção e Substituição de Outliers dos dados, após o
% preenchimento de falhas e blending com suavização.
%
% Aplicação: Dados de CORRENTES MARINHAS medidas pelo ADCP da Bóia BH07,
% Baía de Guanabara, RJ - Brasil.
%
% Este script realiza a detecção e substituição de outliers nos dados
% pré-processados, utilizando análise de derivadas e ajuste local com
% valores médios, garantindo a continuidade e qualidade da série temporal.
%
% Hatsue Takanaca de Decco, Abril/2025.
% Contribuições de IA:
% ------------------------------------------------------------
% Este script foi desenvolvido com o auxílio da inteligência
% artificial ChatGPT (OpenAI) e Grok (xAI), em maio de 2025,
% e Gemini (Gooogle AI) em junho de 2025. 
% A lógica foi construída a partir de instruções e ajustes
% fornecidos pela pesquisadora, garantindo coerência com os
% objetivos e critérios do estudo.
%
% A coautoria simbólica da IA é reconhecida no aspecto técnico,
% sem implicar autoria científica ou responsabilidade intelectual.
% ------------------------------------------------------------
%
% Dados de Correntes Marinhas na "superfície":
% - Frequência amostral: 5 minutos.
% - Período: 01/01/2020 às 00:00h a 31/12/2024 às 23:55h.
% - Colunas: 1  2   3   4  5  6   7   8
% - Formato: DD,MM,YYYY,HH,MM,SS, Direção em graus (Norte geográfico - 0º),
% Intensidade em nós.
%
% ATENÇÃO:
% 1) Sobre o caminho e formato dos dados:
% Defina o caminho dos seus dados na variável abaixo "data_dir". Os dados
% devem estar no formato definido acima.
%
%
% ATENÇÃO:
%
% - A definição de outlier e o fator limiar devem ser calibrados conforme
% as características da série analisada.
%
% ETAPA DO FLUXOGRAMA:
% Pós-processamento (etapa 3) - Deve ser executado APÓS:
%   1. Preenchimento de falhas com U-Tide
%      (bloco2_c1_gapfilling_tide_codiga2011.m)
%   2. Blending/suavização de offsets
%      (bloco2_c2_offsets_blending_smooth.m)
%

%% Abertura e Organização dos dados

% === CONFIGURAÇÃO DO USUÁRIO ===
% Defina aqui o nome do arquivo onde estão os dados originais, que
% ainda contém falhas amostrais, para serem preenchidos:
nomedoarquivo = 'Estacao_Guanabara_BH_Boia_07_corr_sup.txt'; % .mat, .txt, etc
% Nome da série de previsão harmônica previamente ajustada com o U-Tide 
% (salva pelo script "bloco1_c1_gapfilling_tide_codiga2011.m"):
arquivo_b1n1 = fullfile(data_dir_b1n1, 'corr_adcp_comtide.mat');
% Nome do arquivo da série com lacunas de dados preenchidas com previsão 
% do U-Tide e após o blending e suavização de offsets
% (salva pelo script "bloco2_c2_offsets_blending_smooth.m"):
arquivo_b1n2 = fullfile(data_dir_b1n2, 'corr_adcp_comtide_posblending.mat');



% Obtendo o caminho completo do script atual:
current_script_path = mfilename('fullpath');

% Extraindo apenas o diretório onde o script está localizado:
[script_dir, ~, ~] = fileparts(current_script_path);

% Definindo o diretório de dados em relação à pasta do script:
% Dados na subpasta 'Dados', dentro da pasta do script:
data_dir = fullfile(script_dir, 'Dados');

% Define o nome do arquivo de dados:
arquivo = fullfile(data_dir, nomedoarquivo);

% Verifica se o arquivo existe antes de carregar
if exist(arquivo, 'file') ~= 2
    error(['\n\n' ...
        '******************************\n' ...
        '***       ATENÇÃO!         ***\n' ...
        '******************************\n' ...
        '\n' ...
        'ARQUIVO NÃO ENCONTRADO!\n\n' ...
        'Verifique se o diretório está correto:\n  %s\n\n' ...
        'E se o nome do arquivo está correto:\n  %s\n\n'], ...
        data_dir, nome_arquivo);
end

[~, ~, ext] = fileparts(arquivo);

switch lower(ext)
    case '.mat'
        % === ATENÇÃO: ===
        % Este comando carrega a **primeira variável** do arquivo .mat:
        vars = whos('-file', arquivo);
        if isempty(vars)
            error('Arquivo MAT não contém variáveis.');
        end
        nome_var = vars(1).name;  % <-- Aqui pega automaticamente a 1ª variável!
        
        % => Garanta que essa variável seja a que contém os dados no formato:
        % DD,MM,YYYY,HH,MM,SS,Nível (metros)
        % Caso não seja, altere 'vars(1).name' para o nome correto da variável.
        
        load(arquivo, nome_var);
        dados = eval(nome_var);
        clear(nome_var);
        
    case '.txt'
        % Arquivo .txt: carrega diretamente como matriz numérica.
        dados = load(arquivo);
        
    otherwise
        error('Formato de arquivo não suportado.');
end


% Defina aqui o caminho para o diretório onde está o arquivo da série com
% lacunas de dados preenchidas com previsão do U-Tide e após o blending e
% suavização de offsets
% (salva pelo script "bloco2_c2_offsets_blending_smooth.m"):
data_dir_b1n2 = 'C:/Users/SEU_NOME/SEUS_DADOS/';

% Verifica se o arquivo existe antes de carregar
if exist(arquivo_b1n2, 'file') ~= 2
    error(['\n\n' ...
        '******************************\n' ...
        '***       ATENÇÃO!         ***\n' ...
        '******************************\n' ...
        '\n' ...
        'ARQUIVO NÃO ENCONTRADO!\n\n' ...
        'Verifique se o diretório está correto:\n  %s\n\n' ...
        'E se o nome do arquivo está correto:\n  %s\n\n'], ...
        data_dir_b1n2, arquivo_b1n2);
end

load(arquivo_b1n2);

%% Definição de parâmetros e variáveis auxiliares:
%
% Explicação sobre o método para entendimento das variáveis a seguir:
%
% Toda a série de correntes é percorrida para identificar potenciais
% Outliers. A série é transformada em primeira derivada, pois a definição
% de Outlier é dada como uma variação brusca no nível do mar, provavelmente
% causada por sinais espúrios ou ondas geradas por passagens de embarcação
% próximo ao local de medição do nível do mar pelo ADCP.
%
% Os Outliers são buscados ao longo de toda a série e testados contra o
% "fator_limiar". Os elementos identificados como Outliers são substituídos
% por um valor médio entre os valores vizinhos.
%

% Renomeia os dados de correntes em um vetor separado:
u_adcp = dados(:,8).*sind(dados(:,7));
v_adcp = dados(:,8).*cosd(dados(:,7));

% Define o fator limiar de variação, acima do qual um ponto será
% considerado outlier:
fator_u = 0.05;
fator_v = 0.05;

% Define o tamanho do vetor de dados (no tempo) para trabalhar:
tamanho_tempo_total = length(dados(:,7));

% Vetor temporal total (base de referência):
tempo_total_vetorial = 1:tamanho_tempo_total;

% Tamanho da série para a substituição de Outliers:
roda_varredura_outlier = tamanho_tempo_total;

% Inicializa contador de outliers:
conta_outliers_corr = 1;

% Cria a variável de trabalho dos outliers:
u_adcp = u_adcp_comtide;
v_adcp = v_adcp_comtide;

% Cópia do original para comparação posterior:
u_adcp_orig = u_adcp;
v_adcp_orig = v_adcp;

% Adiciona valor de +100 para forçar todos os dados a positivos:
u_adcp = u_adcp + 100;
v_adcp = v_adcp + 100;


%% Detecção e substituição de Outliers:
%
% Lógica:
% 1. Calcula diferenças entre pontos consecutivos (primeira derivada)
% 2. Identifica pontos onde a diferença excede "fator_limiar"
% 3. Substitui outliers por média local (para 1 ponto) 

%
% U:
%

% Inicializa variáveis do Loop principal
% Armazena posições dos outliers corrigidos:
outliers_unicos_nivel = [];

fprintf('\nIniciando detecção e substituição de outliers em U...\n');

conta_outliers_u=1;

% Calcula diferença temporal do dado:
diff_corr_int_nao_nan_u = diff(u_adcp);

% Identifica pontos com diff acima do limiar (potenciais outliers) pela
% primeira vez:
idx_outliers_candidatos = find(abs(diff_corr_int_nao_nan_u) >= fator_u);

if length(idx_outliers_candidatos) > 0
    condicao_outlier_u = true;
    % Corrige índices relativos para absolutos:
    idx_outliers_candidatos = idx_outliers_candidatos + 1;
end

conta_loop_u = 1;

while condicao_outlier_u
    
    fprintf('Loop de Outlier U - Passagem %.0f\n',conta_loop_u);

    for ii=1:length(idx_outliers_candidatos)
        %corrige o outlier:
        outlier = u_adcp(idx_outliers_candidatos(ii));
        
        u_adcp(idx_outliers_candidatos(ii))= ( (u_adcp(idx_outliers_candidatos(ii)+1)) + ...
            (u_adcp(idx_outliers_candidatos(ii)-1)) )/2;
        
        outlier_corrigido = u_adcp(idx_outliers_candidatos(ii));
        fprintf('Outlier corrigido: de %.6f para %.6f em %.f\n', outlier,outlier_corrigido,idx_outliers_candidatos(ii));
        
        outliers_unicos_u(conta_outliers_u)=idx_outliers_candidatos(ii);
        conta_outliers_u = conta_outliers_u + 1;
        
        idx_outliers_candidatos = ...
            find(abs(diff_corr_int_nao_nan_u) >= fator_u);
    end
    
    % Identifica pontos com diff acima do limiar (potenciais outliers) 
    % repetidamente até substituir todos:
    idx_outliers_candidatos = find(abs(diff_corr_int_nao_nan_u) >= fator_u);
    
    if length(idx_outliers_candidatos) > 0
        condicao_outlier_u = true;
        % Corrige índices relativos para absolutos:
        idx_outliers_candidatos = idx_outliers_candidatos + 1;
        conta_loop_u = conta_loop_u +1;
    end
    
end

%
% V:
%

% Inicializa variáveis do Loop principal
% Armazena posições dos outliers corrigidos:
outliers_unicos_nivel = [];

fprintf('\nIniciando detecção e substituição de outliers em V...\n');

conta_outliers_v=1;

% Calcula diferença temporal do dado:
diff_corr_int_nao_nan_v = diff(v_adcp);

% Identifica pontos com diff acima do limiar (potenciais outliers) pela
% primeira vez:
idx_outliers_candidatos = find(abs(diff_corr_int_nao_nan_v) >= fator_v);

if length(idx_outliers_candidatos) > 0
    condicao_outlier_v = true;
    % Corrige índices relativos para absolutos:
    idx_outliers_candidatos = idx_outliers_candidatos + 1;
end

conta_loop_v = 1;

while condicao_outlier_v
    
    fprintf('Loop de Outlier V - Passagem %.0f\n',conta_loop_v);

    for ii=1:length(idx_outliers_candidatos)
        %corrige o outlier:
        outlier = v_adcp(idx_outliers_candidatos(ii));
        
        v_adcp(idx_outliers_candidatos(ii))= ( (v_adcp(idx_outliers_candidatos(ii)+1)) + ...
            (v_adcp(idx_outliers_candidatos(ii)-1)) )/2;
        
        outlier_corrigido = v_adcp(idx_outliers_candidatos(ii));
        fprintf('Outlier corrigido: de %.6f para %.6f em %.f\n', outlier,outlier_corrigido,idx_outliers_candidatos(ii));
        
        outliers_unicos_v(conta_outliers_v)=idx_outliers_candidatos(ii);
        conta_outliers_v = conta_outliers_v + 1;
        
        idx_outliers_candidatos = ...
            find(abs(diff_corr_int_nao_nan_v) >= fator_v);
    end
    
    % Identifica pontos com diff acima do limiar (potenciais outliers) 
    % repetidamente até substituir todos:
    idx_outliers_candidatos = find(abs(diff_corr_int_nao_nan_v) >= fator_v);
    
    if length(idx_outliers_candidatos) > 0
        condicao_outlier_v = true;
        % Corrige índices relativos para absolutos:
        idx_outliers_candidatos = idx_outliers_candidatos + 1;
        conta_loop_v = conta_loop_v +1;
    end
    
end

% Subtrai o valor de 100 da variável de corrente trabalhada:
u_adcp = u_adcp - 100;
v_adcp = v_adcp - 100;

u_adcp_limpo=u_adcp;
v_adcp_limpo = v_adcp;

%% Figuras:
% Figura 1: Comparação do sinal original e do sinal limpo de nível do mar,
% em um bloco selecionado da série temporal. A limpeza substitui outliers
% individuais detectados via média simples.
%
% A linha vermelha representa o dado original, e a azul o sinal corrigido.
figure(1)
clf
hold on
plot(tempo_total_vetorial,u_adcp_orig,'-r')
plot(tempo_total_vetorial,u_adcp_limpo)
grid;
axis tight;
xlabel('Tempo - Dt = 5 minutos');
ylabel('Corrente (knots)');
title(['Componente Zonal U da Velocidade (nós), Limiar de Outlier: ',num2str(limiar_corr_int_u_nao_nan),' ']);

% Figura 2: Diferença temporal entre pontos consecutivos da série (diff).
% Essa análise evidencia as variações bruscas, auxiliando na detecção
% de outliers. Sinais suavizados devem apresentar diffs mais homogêneos.
%
% Aqui, comparando diff antes e depois da limpeza dos dados.
figure(2)
clf
hold
plot(tempo_total_vetorial(2:end),diff(u_adcp_orig),'r')
plot(tempo_total_vetorial(2:end),diff(u_adcp_limpo))
axis tight;
xlabel('Tempo - Dt = 5 minutos');
ylabel('Diferença de U (knots)');
grid;
title(['Diferença da Componente Zonal U da Velocidade (nós)']);

figure(3)
clf
hold on
plot(tempo_total_vetorial,v_adcp_orig,'-r')
plot(tempo_total_vetorial,v_adcp_limpo)
grid;
axis tight;
xlabel('Tempo - Dt = 5 minutos');
ylabel('Corrente (knots)');
title(['Componente Zonal V da Velocidade (nós), Limiar de Outlier: ',num2str(limiar_corr_int_v_nao_nan),' ']);

% Figura 2: Diferença temporal entre pontos consecutivos da série (diff).
% Essa análise evidencia as variações bruscas, auxiliando na detecção
% de outliers. Sinais suavizados devem apresentar diffs mais homogêneos.
%
% Aqui, comparando diff antes e depois da limpeza dos dados.
figure(4)
clf
hold
plot(tempo_total_vetorial(2:end),diff(v_adcp_orig),'r')
plot(tempo_total_vetorial(2:end),diff(v_adcp_limpo))
axis tight;
xlabel('Tempo - Dt = 5 minutos');
ylabel('Diferença de V (knots)');
grid;
title(['Diferença da Componente Zonal V da Velocidade (nós)']);

%% Análises Quantitativas da Remoção de Outliers:

outliers_u_corrigidos = unique(outliers_unicos_u);
outliers_v_corrigidos = unique(outliers_unicos_v);

% Porcentagem total de pontos de outliers em relação ao total de dados:
quantidade_unica_outliers_u = length(unique(outliers_unicos_u));
quantidade_unica_outliers_v = length(unique(outliers_unicos_v));
porcentagem_outliers_u = (((quantidade_unica_outliers_u))/fim_number_index_u(end));
porcentagem_outliers_v = (((quantidade_unica_outliers_v))/fim_number_index_v(end));
fprintf('Porcentagem total de outliers de U: %.6f\n', porcentagem_outliers_u);
fprintf('Porcentagem total de outliers de V: %.6f\n', porcentagem_outliers_v);

% Estatística básica de antes e depois dos outliers:
% média:
media_u_antes=mean(u_adcp_orig);
media_v_antes=mean(v_adcp_orig);
media_u_depois=mean(u_adcp_limpo);
media_v_depois=mean(v_adcp_limpo);
fprintf('Média antes e depois, de U: %.6f e %.6f\n', media_u_antes, media_u_depois);
fprintf('Média antes e depois, de V: %.6f e %.6f\n', media_v_antes, media_v_depois);

% std:
std_u_antes=std(u_adcp_orig);
std_v_antes=std(v_adcp_orig);
std_u_depois=std(u_adcp_limpo);
std_v_depois=std(v_adcp_limpo);
fprintf('STD antes e depois de U: %.6f e %.6f\n', std_u_antes, std_u_depois);
fprintf('STD antes e depois de V: %.6f e %.6f\n', std_v_antes, std_v_depois);

figure(5)
clf
hold on
plot(tempo_total_vetorial(outliers_u_corrigidos), u_adcp_orig(outliers_u_corrigidos), 'r')
plot(tempo_total_vetorial(outliers_u_corrigidos), u_adcp_limpo(outliers_u_corrigidos), 'b')
title(['Outliers detectados - U'])

figure(6)
clf
hold on
plot(tempo_total_vetorial(outliers_v_corrigidos), v_adcp_orig(outliers_v_corrigidos), 'r')
plot(tempo_total_vetorial(outliers_v_corrigidos), v_adcp_limpo(outliers_v_corrigidos), 'b')
title(['Outliers detectados - V'])

%% Salva as variáveis

% Formato .mat:

%vetor com as datas em formato datenum:
vetor_datas_num=datenum(dados(:,3),dados(:,2),dados(:,1),dados(:,4),dados(:,5),dados(:,6)); 

save('corr_adcp_limpo.mat','u_adcp_limpo','v_adcp_limpo','outliers_nivel_corrigidos','vetor_datas_num');


