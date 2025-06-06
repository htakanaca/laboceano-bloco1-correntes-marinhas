%
% Bloco 2 - Scripts de Processamento LabOceano
%
% Passo 3: Detec��o e Substitui��o de Outliers dos dados, ap�s o
% preenchimento de falhas e blending com suaviza��o.
%
% Aplica��o: Dados de CORRENTES MARINHAS medidas pelo ADCP da B�ia BH07,
% Ba�a de Guanabara, RJ - Brasil.
%
% Este script realiza a detec��o e substitui��o de outliers nos dados
% pr�-processados, utilizando an�lise de derivadas e ajuste local com
% valores m�dios, garantindo a continuidade e qualidade da s�rie temporal.
%
% Hatsue Takanaca de Decco, Abril/2025.
% Contribui��es de IA:
% ------------------------------------------------------------
% Este script foi desenvolvido com o aux�lio da intelig�ncia
% artificial ChatGPT (OpenAI) e Grok (xAI), em maio de 2025,
% e Gemini (Gooogle AI) em junho de 2025. 
% A l�gica foi constru�da a partir de instru��es e ajustes
% fornecidos pela pesquisadora, garantindo coer�ncia com os
% objetivos e crit�rios do estudo.
%
% A coautoria simb�lica da IA � reconhecida no aspecto t�cnico,
% sem implicar autoria cient�fica ou responsabilidade intelectual.
% ------------------------------------------------------------
%
% Dados de Correntes Marinhas na "superf�cie":
% - Frequ�ncia amostral: 5 minutos.
% - Per�odo: 01/01/2020 �s 00:00h a 31/12/2024 �s 23:55h.
% - Colunas: 1  2   3   4  5  6   7   8
% - Formato: DD,MM,YYYY,HH,MM,SS, Dire��o em graus (Norte geogr�fico - 0�),
% Intensidade em n�s.
%
% ATEN��O:
% 1) Sobre o caminho e formato dos dados:
% Defina o caminho dos seus dados na vari�vel abaixo "data_dir". Os dados
% devem estar no formato definido acima.
%
%
% ATEN��O:
%
% - A defini��o de outlier e o fator limiar devem ser calibrados conforme
% as caracter�sticas da s�rie analisada.
%
% ETAPA DO FLUXOGRAMA:
% P�s-processamento (etapa 3) - Deve ser executado AP�S:
%   1. Preenchimento de falhas com U-Tide
%      (bloco2_c1_gapfilling_tide_codiga2011.m)
%   2. Blending/suaviza��o de offsets
%      (bloco2_c2_offsets_blending_smooth.m)
%

%% Abertura e Organiza��o dos dados

% === CONFIGURA��O DO USU�RIO ===
% Defina aqui o nome do arquivo onde est�o os dados originais, que
% ainda cont�m falhas amostrais, para serem preenchidos:
nomedoarquivo = 'Estacao_Guanabara_BH_Boia_07_corr_sup.txt'; % .mat, .txt, etc
% Nome da s�rie de previs�o harm�nica previamente ajustada com o U-Tide 
% (salva pelo script "bloco1_c1_gapfilling_tide_codiga2011.m"):
arquivo_b1n1 = fullfile(data_dir_b1n1, 'corr_adcp_comtide.mat');
% Nome do arquivo da s�rie com lacunas de dados preenchidas com previs�o 
% do U-Tide e ap�s o blending e suaviza��o de offsets
% (salva pelo script "bloco2_c2_offsets_blending_smooth.m"):
arquivo_b1n2 = fullfile(data_dir_b1n2, 'corr_adcp_comtide_posblending.mat');



% Obtendo o caminho completo do script atual:
current_script_path = mfilename('fullpath');

% Extraindo apenas o diret�rio onde o script est� localizado:
[script_dir, ~, ~] = fileparts(current_script_path);

% Definindo o diret�rio de dados em rela��o � pasta do script:
% Dados na subpasta 'Dados', dentro da pasta do script:
data_dir = fullfile(script_dir, 'Dados');

% Define o nome do arquivo de dados:
arquivo = fullfile(data_dir, nomedoarquivo);

% Verifica se o arquivo existe antes de carregar
if exist(arquivo, 'file') ~= 2
    error(['\n\n' ...
        '******************************\n' ...
        '***       ATEN��O!         ***\n' ...
        '******************************\n' ...
        '\n' ...
        'ARQUIVO N�O ENCONTRADO!\n\n' ...
        'Verifique se o diret�rio est� correto:\n  %s\n\n' ...
        'E se o nome do arquivo est� correto:\n  %s\n\n'], ...
        data_dir, nome_arquivo);
end

[~, ~, ext] = fileparts(arquivo);

switch lower(ext)
    case '.mat'
        % === ATEN��O: ===
        % Este comando carrega a **primeira vari�vel** do arquivo .mat:
        vars = whos('-file', arquivo);
        if isempty(vars)
            error('Arquivo MAT n�o cont�m vari�veis.');
        end
        nome_var = vars(1).name;  % <-- Aqui pega automaticamente a 1� vari�vel!
        
        % => Garanta que essa vari�vel seja a que cont�m os dados no formato:
        % DD,MM,YYYY,HH,MM,SS,N�vel (metros)
        % Caso n�o seja, altere 'vars(1).name' para o nome correto da vari�vel.
        
        load(arquivo, nome_var);
        dados = eval(nome_var);
        clear(nome_var);
        
    case '.txt'
        % Arquivo .txt: carrega diretamente como matriz num�rica.
        dados = load(arquivo);
        
    otherwise
        error('Formato de arquivo n�o suportado.');
end


% Defina aqui o caminho para o diret�rio onde est� o arquivo da s�rie com
% lacunas de dados preenchidas com previs�o do U-Tide e ap�s o blending e
% suaviza��o de offsets
% (salva pelo script "bloco2_c2_offsets_blending_smooth.m"):
data_dir_b1n2 = 'C:/Users/SEU_NOME/SEUS_DADOS/';

% Verifica se o arquivo existe antes de carregar
if exist(arquivo_b1n2, 'file') ~= 2
    error(['\n\n' ...
        '******************************\n' ...
        '***       ATEN��O!         ***\n' ...
        '******************************\n' ...
        '\n' ...
        'ARQUIVO N�O ENCONTRADO!\n\n' ...
        'Verifique se o diret�rio est� correto:\n  %s\n\n' ...
        'E se o nome do arquivo est� correto:\n  %s\n\n'], ...
        data_dir_b1n2, arquivo_b1n2);
end

load(arquivo_b1n2);

%% Defini��o de par�metros e vari�veis auxiliares:
%
% Explica��o sobre o m�todo para entendimento das vari�veis a seguir:
%
% Toda a s�rie de correntes � percorrida para identificar potenciais
% Outliers. A s�rie � transformada em primeira derivada, pois a defini��o
% de Outlier � dada como uma varia��o brusca no n�vel do mar, provavelmente
% causada por sinais esp�rios ou ondas geradas por passagens de embarca��o
% pr�ximo ao local de medi��o do n�vel do mar pelo ADCP.
%
% Os Outliers s�o buscados ao longo de toda a s�rie e testados contra o
% "fator_limiar". Os elementos identificados como Outliers s�o substitu�dos
% por um valor m�dio entre os valores vizinhos.
%

% Renomeia os dados de correntes em um vetor separado:
u_adcp = dados(:,8).*sind(dados(:,7));
v_adcp = dados(:,8).*cosd(dados(:,7));

% Define o fator limiar de varia��o, acima do qual um ponto ser�
% considerado outlier:
fator_u = 0.05;
fator_v = 0.05;

% Define o tamanho do vetor de dados (no tempo) para trabalhar:
tamanho_tempo_total = length(dados(:,7));

% Vetor temporal total (base de refer�ncia):
tempo_total_vetorial = 1:tamanho_tempo_total;

% Tamanho da s�rie para a substitui��o de Outliers:
roda_varredura_outlier = tamanho_tempo_total;

% Inicializa contador de outliers:
conta_outliers_corr = 1;

% Cria a vari�vel de trabalho dos outliers:
u_adcp = u_adcp_comtide;
v_adcp = v_adcp_comtide;

% C�pia do original para compara��o posterior:
u_adcp_orig = u_adcp;
v_adcp_orig = v_adcp;

% Adiciona valor de +100 para for�ar todos os dados a positivos:
u_adcp = u_adcp + 100;
v_adcp = v_adcp + 100;


%% Detec��o e substitui��o de Outliers:
%
% L�gica:
% 1. Calcula diferen�as entre pontos consecutivos (primeira derivada)
% 2. Identifica pontos onde a diferen�a excede "fator_limiar"
% 3. Substitui outliers por m�dia local (para 1 ponto) 

%
% U:
%

% Inicializa vari�veis do Loop principal
% Armazena posi��es dos outliers corrigidos:
outliers_unicos_nivel = [];

fprintf('\nIniciando detec��o e substitui��o de outliers em U...\n');

conta_outliers_u=1;

% Calcula diferen�a temporal do dado:
diff_corr_int_nao_nan_u = diff(u_adcp);

% Identifica pontos com diff acima do limiar (potenciais outliers) pela
% primeira vez:
idx_outliers_candidatos = find(abs(diff_corr_int_nao_nan_u) >= fator_u);

if length(idx_outliers_candidatos) > 0
    condicao_outlier_u = true;
    % Corrige �ndices relativos para absolutos:
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
    % repetidamente at� substituir todos:
    idx_outliers_candidatos = find(abs(diff_corr_int_nao_nan_u) >= fator_u);
    
    if length(idx_outliers_candidatos) > 0
        condicao_outlier_u = true;
        % Corrige �ndices relativos para absolutos:
        idx_outliers_candidatos = idx_outliers_candidatos + 1;
        conta_loop_u = conta_loop_u +1;
    end
    
end

%
% V:
%

% Inicializa vari�veis do Loop principal
% Armazena posi��es dos outliers corrigidos:
outliers_unicos_nivel = [];

fprintf('\nIniciando detec��o e substitui��o de outliers em V...\n');

conta_outliers_v=1;

% Calcula diferen�a temporal do dado:
diff_corr_int_nao_nan_v = diff(v_adcp);

% Identifica pontos com diff acima do limiar (potenciais outliers) pela
% primeira vez:
idx_outliers_candidatos = find(abs(diff_corr_int_nao_nan_v) >= fator_v);

if length(idx_outliers_candidatos) > 0
    condicao_outlier_v = true;
    % Corrige �ndices relativos para absolutos:
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
    % repetidamente at� substituir todos:
    idx_outliers_candidatos = find(abs(diff_corr_int_nao_nan_v) >= fator_v);
    
    if length(idx_outliers_candidatos) > 0
        condicao_outlier_v = true;
        % Corrige �ndices relativos para absolutos:
        idx_outliers_candidatos = idx_outliers_candidatos + 1;
        conta_loop_v = conta_loop_v +1;
    end
    
end

% Subtrai o valor de 100 da vari�vel de corrente trabalhada:
u_adcp = u_adcp - 100;
v_adcp = v_adcp - 100;

u_adcp_limpo=u_adcp;
v_adcp_limpo = v_adcp;

%% Figuras:
% Figura 1: Compara��o do sinal original e do sinal limpo de n�vel do mar,
% em um bloco selecionado da s�rie temporal. A limpeza substitui outliers
% individuais detectados via m�dia simples.
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
title(['Componente Zonal U da Velocidade (n�s), Limiar de Outlier: ',num2str(limiar_corr_int_u_nao_nan),' ']);

% Figura 2: Diferen�a temporal entre pontos consecutivos da s�rie (diff).
% Essa an�lise evidencia as varia��es bruscas, auxiliando na detec��o
% de outliers. Sinais suavizados devem apresentar diffs mais homog�neos.
%
% Aqui, comparando diff antes e depois da limpeza dos dados.
figure(2)
clf
hold
plot(tempo_total_vetorial(2:end),diff(u_adcp_orig),'r')
plot(tempo_total_vetorial(2:end),diff(u_adcp_limpo))
axis tight;
xlabel('Tempo - Dt = 5 minutos');
ylabel('Diferen�a de U (knots)');
grid;
title(['Diferen�a da Componente Zonal U da Velocidade (n�s)']);

figure(3)
clf
hold on
plot(tempo_total_vetorial,v_adcp_orig,'-r')
plot(tempo_total_vetorial,v_adcp_limpo)
grid;
axis tight;
xlabel('Tempo - Dt = 5 minutos');
ylabel('Corrente (knots)');
title(['Componente Zonal V da Velocidade (n�s), Limiar de Outlier: ',num2str(limiar_corr_int_v_nao_nan),' ']);

% Figura 2: Diferen�a temporal entre pontos consecutivos da s�rie (diff).
% Essa an�lise evidencia as varia��es bruscas, auxiliando na detec��o
% de outliers. Sinais suavizados devem apresentar diffs mais homog�neos.
%
% Aqui, comparando diff antes e depois da limpeza dos dados.
figure(4)
clf
hold
plot(tempo_total_vetorial(2:end),diff(v_adcp_orig),'r')
plot(tempo_total_vetorial(2:end),diff(v_adcp_limpo))
axis tight;
xlabel('Tempo - Dt = 5 minutos');
ylabel('Diferen�a de V (knots)');
grid;
title(['Diferen�a da Componente Zonal V da Velocidade (n�s)']);

%% An�lises Quantitativas da Remo��o de Outliers:

outliers_u_corrigidos = unique(outliers_unicos_u);
outliers_v_corrigidos = unique(outliers_unicos_v);

% Porcentagem total de pontos de outliers em rela��o ao total de dados:
quantidade_unica_outliers_u = length(unique(outliers_unicos_u));
quantidade_unica_outliers_v = length(unique(outliers_unicos_v));
porcentagem_outliers_u = (((quantidade_unica_outliers_u))/fim_number_index_u(end));
porcentagem_outliers_v = (((quantidade_unica_outliers_v))/fim_number_index_v(end));
fprintf('Porcentagem total de outliers de U: %.6f\n', porcentagem_outliers_u);
fprintf('Porcentagem total de outliers de V: %.6f\n', porcentagem_outliers_v);

% Estat�stica b�sica de antes e depois dos outliers:
% m�dia:
media_u_antes=mean(u_adcp_orig);
media_v_antes=mean(v_adcp_orig);
media_u_depois=mean(u_adcp_limpo);
media_v_depois=mean(v_adcp_limpo);
fprintf('M�dia antes e depois, de U: %.6f e %.6f\n', media_u_antes, media_u_depois);
fprintf('M�dia antes e depois, de V: %.6f e %.6f\n', media_v_antes, media_v_depois);

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

%% Salva as vari�veis

% Formato .mat:

%vetor com as datas em formato datenum:
vetor_datas_num=datenum(dados(:,3),dados(:,2),dados(:,1),dados(:,4),dados(:,5),dados(:,6)); 

save('corr_adcp_limpo.mat','u_adcp_limpo','v_adcp_limpo','outliers_nivel_corrigidos','vetor_datas_num');


