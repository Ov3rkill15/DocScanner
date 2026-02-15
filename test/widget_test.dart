import 'namahewan.dart';

void main() {
  Kucing hewan1 = Kucing(berat: 10, jumlahKaki: 4, kecepatanlari: 10);
  Burung hewan2 = Burung(berat: 2, jumlahKaki: 2);
  Ikan hewan3 = Ikan(berat: 1, jumlahSirip: 2, kecepatanRenang: 10);

  hewan1.printInfo();
  hewan1.detail();
  hewan1.makan = 2;
  print("\n");
  hewan2.printInfo();
  hewan2.detail();
  hewan2.makan = 3;
  print("\n");
  hewan3.printInfo();
  hewan3.detail();
  hewan3.makan = 4;
}
