# Maintainer scripts

## `fix-git-and-push.ps1`

Чинит типичные проблемы и пушит в GitHub:

- `safe.directory` (dubious ownership)
- GPG signing hang / `gpg failed to sign` → **выключает signing только в этом репо**
- `user.name` / `user.email` если пустые
- remote `origin`
- smoke tests
- commit (по запросу) + `git push`
- опционально тег → auto-release

```powershell
cd D:\PowerShell

# Обычный fix + push main
pwsh -NoProfile -File .\scripts\fix-git-and-push.ps1

# Без smoke / без push
pwsh -NoProfile -File .\scripts\fix-git-and-push.ps1 -SkipSmoke
pwsh -NoProfile -File .\scripts\fix-git-and-push.ps1 -SkipPush

# Запушить + тег релиза
pwsh -NoProfile -File .\scripts\fix-git-and-push.ps1 -Tag v5.1.4

# Если GPG снова отвалился
pwsh -NoProfile -File .\scripts\fix-git-and-push.ps1 -NoGpgSign
```

Identity (this repo): **Vadim Khristenko** `<vadim@vai-rice.space>`

### Если GPG снова мешает вручную

```powershell
cd D:\PowerShell
# временно
git config commit.gpgsign false
git commit --no-gpg-sign -m "your message"

# обратно (когда agent разлочен)
git config commit.gpgsign true
git config tag.gpgsign true
```

### Если gh не залогинен

```powershell
gh auth login
gh auth status
```
