# Causa raiz — build demorado (2026-11-17)

## Resumo

O gate t2 (verification/build) levou ~1h. **Não foi o mesmo erro repetido** — foi uma cascata
de dependências desencadeada por UMA causa raiz, com cada fix revelando o próximo erro.

## Causa raiz única

Migração pro Linux (CachyOS) instalou **Flutter 3.50.0 / AGP 9+**. O projeto foi
desenvolvido contra Flutter mais antigo (Windows, `D:\urutau-devtools\flutter`).
Os pacotes Android no pub cache local usavam o **plugin `kotlin-android` antigo**,
que o AGP 9 rejeita:

```
image_picker_android 0.8.13+17  ->  kotlin-android plugin  ->  AGP 9  ->  BUILD FAILED
```

Enquanto no Windows o cache tinha as mesmas versões antigas, o AGP lá também era antigo →
compatível. A troca de host quebrou a combinação.

## Cascata (cada passo um erro novo, não repetição)

| Passo | Ação | Erro novo exposto |
|-------|------|-------------------|
| 1 | upgrade `image_picker 1.2.2 → 1.2.4` | `package_info_plus 9.0.1` ainda com kotlin-android |
| 2 | dependency_overrides `image_picker_android 0.8.13+25` | `package_info_plus 9.0.1` kotlin-android |
| 3 | upgrade `package_info_plus 9 → 10.2.2` | conflito `win32 ^6.x` vs `share_plus 13.3.1` que quer `win32 ^5.x` |
| 4 | upgrade `share_plus 13.3.1 → 13.3.2+` | `file_picker` subiu pra 13.x e **mudou a API** (`FilePicker.platform` removido, `pickFiles` devolve `List<PlatformFile>` direto, `PlatformFile.bytes` virou `readAsBytes()`) |
| 5 | corrigir API em `settings_screen.dart` + `integrity_error_screen.dart` | build OK |

## O erro de decisão (o que merecia crítica)

O primeiro movimento foi **"upgradar tudo"**. O movimento correto era **"pin o que
funcionava"**: `flutter pub get` com `dependency_overrides` apenas nos pacotes Android
que o AGP 9 rejeita, sem tocar em nada que tivesse API. O upgrade do `file_picker`
arrastou 2 arquivos de código (`FilePicker.platform` → `FilePickerPlatform.instance`)
que não precisavam ter sido mexidos.

**Regra pra próxima:** em host novo, PRIMEIRO isolar o pacote quebrado com
`dependency_overrides` e buildar. Só depois, se sobrar tempo, atualizar APIs.

## Estado final verificado pelo capitão (independente do verifier)

- SHA256: `982f25f89e7d8a83dd3dcbef09f5e161bd5c1adaacfae029880e5d738d030fa7`
- Assinatura: `CN=Urutau, OU=Dev, O=Badger` (apksigner verify PASS, v2)
- `com.urutau.app` versionCode=4 versionName=2.0.2
- Tamanho: 71.0 MB
- `flutter analyze --no-fatal-infos`: 0 erros
- `flutter test`: 229 pass (golden excluded — precisam de imagens de baseline)