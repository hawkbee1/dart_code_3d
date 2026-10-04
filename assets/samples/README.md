# Sample code map

`sample.dc3d` is the code map of a small weather app (47 top-level declarations, 159 nodes), opened by **Open sample** on the home screen and used by the
`sample_start`, `fly_path`, `links_*` and `inside_*` 3D visual tests. Its `WeatherCache` holds three
methods and a nested subclass (`PersistentWeatherCache`), the case the `inside_*` scenarios fly into.

Its source is `tool/sample/sample_source.txt` (one `=== <path>` header per file).
Rebuild the map after changing the source or the engine:

```sh
apps/dart_code_3d/tool/sample/build_sample.sh
```

The script unpacks the source into a temporary folder and runs the engine and layout
CLIs:

```sh
dart run code_analysis_engine:analyze <folder> --out graph.json --stats
dart run code_layout:layout graph.json --out assets/samples/sample.dc3d
```
