# commit-fase.ps1
#
# Wrapper para commit + push das fases do projeto.
#
# USO (dot-source primeiro):
#   . .\commit-fase.ps1
#   Commit-Fase -Titulo "Fase X.Y: descricao" -Arquivos @("arq1", "arq2") -AutoPush
#
# Ver exemplos em: setup/EXEMPLOS_COMMIT_FASE.md

function Commit-Fase {
    param(
        [Parameter(Mandatory=$true)]
        [string]$Titulo,
        [Parameter(Mandatory=$true)]
        [string[]]$Arquivos,
        [switch]$AutoPush,
        [string]$Repo = "mariocezar1971/livro-doe-usinagem"
    )

    $adicionados = 0
    foreach ($f in $Arquivos) {
        $matches = Get-ChildItem -Path $f -ErrorAction SilentlyContinue
        if ($matches) {
            foreach ($m in $matches) {
                git add $m.FullName
                Write-Host "[+] $($m.Name)" -ForegroundColor Green
                $adicionados++
            }
        } elseif (Test-Path $f) {
            git add $f
            Write-Host "[+] $f" -ForegroundColor Green
            $adicionados++
        } else {
            Write-Host "[!] $f nao existe" -ForegroundColor Yellow
        }
    }

    if ($adicionados -eq 0) {
        Write-Host "`n[X] Nenhum arquivo adicionado - abortando" -ForegroundColor Red
        return
    }

    Write-Host "`n=== Arquivos staged ===" -ForegroundColor Yellow
    git status --short

    Write-Host "`n=== Estatisticas ===" -ForegroundColor Yellow
    git diff --cached --stat

    if ((Read-Host "`nProsseguir com commit? (S/N)") -ne "S") {
        Write-Host "[i] Commit cancelado. Rode 'git reset HEAD' para reverter staging."
        return
    }

    git commit -m $Titulo

    if ($LASTEXITCODE -ne 0) {
        Write-Host "[X] Commit falhou" -ForegroundColor Red
        return
    }

    Write-Host "`n[OK] Commit criado:" -ForegroundColor Green
    git log --oneline -1

    if ($AutoPush) {
        Write-Host "`n=== Push ===" -ForegroundColor Yellow
        git push
        if ($LASTEXITCODE -eq 0) {
            Write-Host "[OK] Push completo" -ForegroundColor Green
            Start-Sleep -Seconds 5
            Write-Host "`n=== Deploy iniciado ===" -ForegroundColor Yellow
            gh run list --repo $Repo --limit 1
        }
    } else {
        Write-Host "`n[i] Para pushar: git push" -ForegroundColor Cyan
    }
}