# Accelerator manifest summary
Source: accel_manifest.json

| Name | Version | Success | Gated | Source | Gate reason |
| --- | --- | --- | --- | --- | --- |
| sageattention2pp | — | false | false | unsupported | unsupported (SAGEATTENTION2PP_PACKAGE not set) |
| flash-attn | — | false | true | none | unsupported python version 3.13 |
| flash_attn_3 | — | false | true | none | unsupported python version 3.13 |
| sageattention | — | false | true | pypi | D:\a\ComfyUI-Windows-Portable\ComfyUI-Windows-Portable\builder-cu130\python_standalone\Lib\site-packages\torch\cuda\__init__.py:61: FutureWarning: The pynvml package is deprecated. Please install nvidia-ml-py instead. If you did not install pynvml directly, please report this to the maintainers of the package that installed pynvml for you.
  import pynvml  # type: ignore[import]
sageattention: No module named 'triton' |
| sageattention2 | — | false | true | none | unsupported python version 3.13 |
| triton-windows | 3.5.1.post23 | true | false | pypi | — |
