abstract class Hewan {
  String kategori;
  String? nama;
  late int _berat;

  Hewan({required int berat, required this.kategori, required this.nama}) {
    _berat = berat;
  }

  int get berat => _berat;

  set makan(int beratMakan) {
    _berat += beratMakan;
    print("Sehabis makan beratnya jadi: ${this.berat} KG");
  }

  void printInfo() {
    print(
      "Nama: ${this.nama} - Kategori: ${this.kategori} dengan berat: ${this.berat} KG",
    );
  }
}




