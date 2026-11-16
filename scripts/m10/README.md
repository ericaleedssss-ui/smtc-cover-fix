# Rhine M10 recovery build

The recovery starts at aebdfe68a9780988dd8c30c37047dc19e75b0146. We recovered documented M10 sections and checked them against the surviving source and Type-C overlay. The original dirty build tree is unavailable.

Build on Windows with PowerShell 7 and Go 1.27.3. From the source root, provide a toolchain and a new output directory.

```powershell
./scripts/m10/build.ps1 -Go C:/path/to/go.exe -OutputDirectory ../candidate
./scripts/m10/build.ps1 -Go C:/path/to/go.exe -OutputDirectory ../typec -Mode TypeC
```

Keep the output resources directory beside the executable. The builds share product code, fonts and the checked MyGo dependency. TypeC adds only the display positioning hook. Launch the ordinary executable for normal window placement. The script saves the build command, dependency checksum, patch checksum, source commit, artifact checksum and resource hashes to manifest.json.

The independent mygo.patch reproduces the surviving refresh timing, D3D11 texture retention, and wheel retargeting overlays and includes the texture regression test. It omits forced frame logging. This candidate uses the complete patch configuration to evaluate the previous Type-C experience. Individual patches still need release validation.

The recovery excludes later discovery, song detail, comments, profile, password login, collection, queue, desktop settings, font import and performance panel changes. Shared changes without clear M10 provenance were left at the baseline, including the application artwork-cache rewrite. The backup retains those changes and the original diagnostic inputs.
