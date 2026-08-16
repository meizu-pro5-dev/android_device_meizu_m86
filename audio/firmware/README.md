# Audio firmware tables

`stage1.txt` and `stage2.txt` are small tuning/coefficient tables extracted
from the verified Meizu Flyme 8.0.5.0A production base (stock archive
SHA-256 `7d1585b86aaf8fd1ab6a5e12f8a3a50f9ed6a759d8f91d51ca1b1d4c13a77a28`).

They are shipped here only because the m86 audio HAL loads them from this
path. The full stock firmware and HAL binaries themselves are **not** part of
this repository; `vendor/meizu/m86/proprietary/` is ignored by Git and is
populated through the explicit extraction workflow described in
`vendor/meizu/m86/README.md`.

If redistribution of these two tables is not acceptable in your jurisdiction,
delete the files and regenerate them from the stock image with the documented
extraction workflow.

## 中文说明

`stage1.txt` / `stage2.txt` 是从已校验的 Flyme 8.0.5.0A 量产固件中提取的
小体积调参/系数表。m86 audio HAL 从该路径加载它们，因此随设备树发布。
完整的 stock 固件与 HAL 二进制不入库；`vendor/meizu/m86/proprietary/`
被 Git 忽略，按 `vendor/meizu/m86/README.md` 的流程显式提取生成。如当地
法规不允许再分发这两个表，请删除后使用文档化提取流程从 stock 镜像重新
生成。
