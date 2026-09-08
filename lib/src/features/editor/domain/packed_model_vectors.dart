import 'dart:collection';
import 'dart:typed_data';

/// Contiguous vectors instead of one growable list and boxed numbers per
/// vertex. List compatibility keeps project JSON and existing model tools valid.
class PackedModelVectors extends ListBase<List<double>> {
  PackedModelVectors(int count, this.components)
    : data = Float64List(count * components);
  final int components;
  final Float64List data;
  @override
  int get length => data.length ~/ components;
  @override
  set length(int value) => throw UnsupportedError('Fixed vector buffer');
  @override
  List<double> operator [](int index) {
    RangeError.checkValidIndex(index, this);
    return Float64List.sublistView(
      data,
      index * components,
      (index + 1) * components,
    );
  }

  @override
  void operator []=(int index, List<double> value) {
    RangeError.checkValidIndex(index, this);
    if (value.length != components) throw ArgumentError('Vector dimension');
    data.setRange(index * components, (index + 1) * components, value);
  }
}
