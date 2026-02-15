import 'hewan.dart';

class Ikan extends Hewan {
  int? jumlahSirip;
  int? kecepatanRenang;

  Ikan({required super.berat, required this.jumlahSirip, this.kecepatanRenang})
    : super(nama: "Paus", kategori: "Mamalia");

  void detail() {
    print(
      "jumlah kaki ada ${this.jumlahSirip} kaki dengan kecepatan ${this.kecepatanRenang}",
    );
  }
}

class Burung extends Hewan {
  int? jumlahKaki;
  int? kecepatanTerbang;

  Burung({required super.berat, required this.jumlahKaki, this.kecepatanTerbang})
    : super(nama: "Merpati", kategori: "Bukan Mamalia");

  void detail() {
    print(
      "jumlah kaki ada ${this.jumlahKaki} kaki dengan kecepatan ${this.kecepatanTerbang}",
    );
  }
}

class Kucing extends Hewan {
  int? jumlahKaki;
  int? kecepatanlari;
  Kucing({required super.berat, required this.jumlahKaki, this.kecepatanlari})
    : super(nama: "Kucing", kategori: "Mamalia");

  void detail() {
    print(
      "jumlah kaki ada ${this.jumlahKaki} kaki dengan kecepatan ${this.kecepatanlari}"
    );
  }
}