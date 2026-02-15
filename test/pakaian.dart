class Pakaian {
  //Atribut
  String? jenis;
  String? warna;
  String? _ukuran;

  //Constructor
  // Pakaian(String J, String W) {
  //   jenis = J;
  //   warna = W;
  // }
  //name argument
  // Pakaian({String? J, String? W}) {
  //   jenis = J;
  //   warna = W;
  // }
  //direct name argument
  Pakaian({this.jenis, this.warna, String? ukuran}) {
    print("constructor berjalan!");
    _ukuran = ukuran;
  }
  //method
  //fungsi set biasa
  void gantiUkuran(String ukuranNew) {
    _ukuran = ukuranNew;
  }

  set setUkuran(String? ukuranNew) {
    _ukuran = ukuranNew;
  }

  //fungsi get biasa
  // String? ukuran() {
  //   return _ukuran;
  // }

  //getter
  get ukuran => _ukuran;
}
