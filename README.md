# Criar Kernel Jupyter Local com ROCm PyTorch

Conjunto simples de scripts para criar um kernel Jupyter local com PyTorch em ROCm.

## Contexto

### Necessidade

Podemos encontrar as seguintes situações:

1. **Python e Jupyter são instalados pelo admin** — O sistema tem uma instalação global de Python (por exemplo, `/usr/bin/python3`) e um servidor Jupyter que todos os usuários compartilham;

2. **Não se tem permissões de root** — Não se pode executar `sudo pip install` para instalar pacotes no Python do sistema, e até mesmo instalações não locais (como !pip ao invés de %pip em kernels para ipynb).

3. **O kernel padrão do Jupyter aponta para o Python do sistema** — Quando se abre um notebook e se tem "Python 3" (ou qualquer outro nome), pode se estar usando o interpretador do sistema, onde não se pode instalar nada.

4. **Pacotes específicos** — No caso de GPUs AMD, precisa-se do PyTorch compilado com suporte ROCm (para o runtime), não a versão padrão (CPU) ou CUDA.

### O que tentamos fazer

Criar um **kernel Jupyter pessoal** que:

- Usa pacotes instalados no seu diretório `$HOME` (não precisa de root)
- Aparece como uma opção no seletor de kernels do Jupyter
- Tem o PyTorch ROCm instalado
- Permite que você instale qualquer pacote adicional que precisar

### Como fazer o Jupyter encontrar kernels

O Jupyter procura kernels em vários lugares, nesta ordem:

1. `~/.local/share/jupyter/kernels/` — **Kernels do usuário** (onde instalamos)
2. `/usr/local/share/jupyter/kernels/` — Kernels locais do sistema
3. `/usr/share/jupyter/kernels/` — Kernels globais do sistema

Quando se executa `python -m ipykernel install --user`, o kernel é registrado em `~/.local/share/jupyter/kernels/`, que não precisa de permissões especiais, pois é local (e daí a vantagem).

### Venv vs. Sem Venv

Oferecemos duas abordagens:

| Abordagem | Prós | Contras |
|-----------|------|---------|
| **Sem venv** (`--user`) | Mais simples, menos espaço em disco | Pacotes compartilhados entre todos os kernels |
| **Com venv** | Ambientes isolados, sem conflitos | Mais espaço em disco, precisa ativar para usar no terminal |

**Use sem venv** se só se precisa de um ambiente de trabalho.

**Use com venv** se se precisa de múltiplos ambientes com versões diferentes de pacotes.

## Estrutura de instalação do arquivo e necessidade da colocação do torch como último

Muitos pacotes de ML têm `torch` como dependência. Quando você instala, por exemplo, `transformers` ou `accelerate`, o pip pode tentar instalar o PyTorch automaticamente — e vai instalar a versão CPU(ou cuda).

Por isso, os scripts:

1. Filtram `torch`, `torchvision` e `torchaudio` do requirements.txt
2. Instalam todos os outros pacotes primeiro
3. Instalam o PyTorch ROCm **por último**, sobrescrevendo qualquer versão errada

## Duas Versões

| Script | Pacotes vão para | Usar quando |
|--------|------------------|-------------|
| `create_kernel_no_venv.sh` | `~/.local/lib/python3.x/` | Setup simples, deps compartilhadas |
| `create_kernel_venv.sh` | `~/venvs/<nome>/` | Ambientes isolados |

## Uso

### Básico (sem venv)

```bash
./create_kernel_no_venv.sh -n meu-kernel
```

### Com venv (isolado)

```bash
./create_kernel_venv.sh -n meu-kernel
```

### Opções

| Flag | Descrição | Padrão |
|------|-----------|--------|
| `-n, --name` | Nome do kernel **(obrigatório)** | - |
| `-r, --rocm` | Versão do ROCm | `rocm6.4` |
| `-f, --file` | Arquivo requirements.txt | - |
| `-h, --help` | Mostrar ajuda | - |

### Exemplos

```bash
# Mínimo
./create_kernel_no_venv.sh -n rocm-ml

# Especificar versão do ROCm
./create_kernel_venv.sh -n gpu-env -r rocm6.3

# Com requirements.txt
./create_kernel_venv.sh -n gpu-env -r rocm6.4 -f requirements.txt
```

### Como verificar o ROCm

Execute no terminal do cluster:

```bash
rocm-smi --version
# ou
cat /opt/rocm/.info/version
```

Versões funcionais atuais na máquina: `rocm7.0', `rocm6.4'

## Após Executar

1. Atualize o Jupyter
2. Selecione o kernel: **"Python (ROCm - nome-do-seu-kernel)"**
3. Verifique:
   ```python
   import torch
   print(torch.__version__)
   print(torch.cuda.is_available())  # Deve ser True
   print(torch.cuda.device_count())  # Deve mostrar suas GPUs
   ```

## Como Funciona

### Passo a passo

1. **Atualiza pip** — Garantir que pip/wheel/setuptools estão atualizados para evitar problemas de instalação.

2. **Instala requirements.txt (filtrado)** — Se fora passado um arquivo com `-f`, ele é instalado, mas linhas com `torch`, `torchvision` ou `torchaudio` são removidas.

3. **Instala PyTorch ROCm** — Instalado POR ÚLTIMO para garantir que a versão ROCm prevaleça sobre qualquer versão que tenha sido instalada como dependência (por isso a remoção no 2.)

4. **Instala ipykernel** — O pacote que permite registrar o ambiente como um kernel Jupyter.

5. **Registra kernel** — Executa `ipykernel install --user`, que cria um arquivo `kernel.json` em `~/.local/share/jupyter/kernels/`.

### pApel do kernel.json?

Quando você registra um kernel, é criado um arquivo assim:

```
~/.local/share/jupyter/kernels/meu-kernel/kernel.json
```

Com conteúdo similar a:

```json
{
  "argv": [
    "/home/usuario/venvs/meu-kernel/bin/python",
    "-m",
    "ipykernel_launcher",
    "-f",
    "{connection_file}"
  ],
  "display_name": "Python (ROCm - meu-kernel)",
  "language": "python"
}
```

Isso diz ao Jupyter qual interpretador Python usar quando você seleciona esse kernel.

## Sobre o requirements.txt

Se você fornecer um requirements.txt com `-f`:

- Linhas começando com `torch`, `torchvision` ou `torchaudio` são **filtradas**
- PyTorch com ROCm é instalado **depois** de todos os outros pacotes
- Isso garante que o PyTorch ROCm nunca seja sobrescrito por versões CPU/CUDA

### Exemplo de requirements.txt

```
transformers==4.40.0
datasets
accelerate
pandas
numpy
tqdm
torch  # <---< Essa linha ignorada!
```

## Instalando Mais Pacotes Depois

### Versão sem venv

```bash
pip install --user algum-pacote
```

### Versão com venv

```bash
source ~/venvs/<nome-do-kernel>/bin/activate
pip install algum-pacote
```

### De uma célula do notebook

```python
# Versão venv (já está no ambiente correto)
!pip install algum-pacote

# Versão sem venv
!pip install --user algum-pacote
```

### Atenção com dependências do torch!

Se você instalar um pacote que depende do torch (ex: `torchmetrics`, `pytorch-lightning`), ele pode tentar instalar a versão CPU. Depois de instalar, reinstale o PyTorch ROCm (como anteriormente de uma célula ou do console do ipynb, ou até mesmo do .venv):

```bash
!pip install torch torchvision torchaudio --index-url https://download.pytorch.org/whl/rocm6.4
```

## Resolução de Problemas

### Kernel não aparece no Jupyter

```bash
# Verificar se o kernel está registrado
jupyter kernelspec list

# Deve mostrar algo como:
#   meu-kernel    /home/usuario/.local/share/jupyter/kernels/meu-kernel
```

Se não aparecer, tente reiniciar o servidor Jupyter ou fazer refresh na página.

### torch.cuda.is_available() retorna False 

Já verificamos, porém cabe documentar

1. Verifique se o ROCm está instalado no host:
   ```bash
   rocm-smi
   ls /dev/kfd
   ```

2. Verifique se você tem acesso na GPU:
   ```bash
   rocminfo | head -40
   ```

3. Verifique a versão correta do PyTorch:
   ```python
   import torch
   print(torch.version.hip)  # Deve mostrar a versão ROCm, não None
   ```

   Se `torch.version.hip` for `None`, você tem a versão CPU ou CUDA instalada.

### Versão errada do PyTorch instalada

Execute o script novamente — ele instala o PyTorch com ROCm por último, sobrescrevendo qualquer versão errada.

Ou manualmente:

```bash
pip uninstall torch torchvision torchaudio
pip install torch torchvision torchaudio --index-url https://download.pytorch.org/whl/rocm6.4
```

### Erro "No module named X" no notebook

O pacote não está instalado no kernel correto. Verifique:

1. Você está usando o kernel certo? (olhe no canto superior direito do Jupyter)
2. Instale o pacote no ambiente correto (veja seção que falamos do "Instalando Mais Pacotes Depois")

### Conflito de versões

Se estiver tendo problemas com conflitos, a versão com venv é mais segura, porque cada ambiente é completamente isolado, então dependendo do número de pessoas e da distinção de pacotes feitas, mas um interpretador básico que cara usuário deriva para si versões específicas não deve ser problemático.

## Desinstalando

### Remover kernel do Jupyter

```bash
jupyter kernelspec uninstall meu-kernel
```

### Remover venv (se usando versão com venv)

```bash
rm -rf ~/venvs/meu-kernel
```

### Remover pacotes do usuário (se usando versão sem venv)

```bash
pip uninstall torch torchvision torchaudio
```

Nota: Remover pacotes instalados com `--user` pode ser trabalhoso se você instalou muitos, por isso a versão com venv é mais fácil de limpar (basta deletar od rietorio).
