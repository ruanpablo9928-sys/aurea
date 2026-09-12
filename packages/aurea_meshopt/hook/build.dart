import 'package:hooks/hooks.dart';
import 'package:native_toolchain_c/native_toolchain_c.dart';

void main(List<String> args) async {
  await build(args, (input, output) async {
    await CBuilder.library(
      name: 'aurea_meshopt',
      assetName: 'aurea_meshopt.dart',
      sources: [
        'src/aurea_meshopt.cpp',
        'src/allocator.cpp',
        'src/vcacheoptimizer.cpp',
      ],
      language: Language.cpp,
      std: 'c++17',
    ).run(input: input, output: output);
  });
}
