class Ingredient {
  String? id;
  String nome;
  String scadenza;
  String note;
  String quantity;
  String unit;
  String genericName;

  Ingredient({
    this.id,
    required this.nome,
    required this.scadenza,
    required this.note,
    required this.quantity,
    this.unit = 'pcs',
    this.genericName = '',
    //il valore '' indica nullo!!! attenzione sull'inserimento nella ricerca ricette
  });

  factory Ingredient.fromJson(Map<String, dynamic> json) {
    return Ingredient(
      id: json['id'],
      nome: json['nome'] ?? '',
      scadenza: json['scadenza'] ?? '',
      note: json['note'] ?? '',
      quantity: json['quantity'] ?? '',
      unit: json['unit'] ?? 'g',
      genericName: json['genericName'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'nome': nome,
      'scadenza': scadenza,
      'note': note,
      'quantity': quantity,
      'unit': unit,
      'genericName': genericName,
    };
  }

  // Helper per ottenere il nome senza parentesi
  String get displayName {
    return nome;
  }

  // Helper per ottenere la quantità
  String get qty {
    return quantity;
  }

  //helper per ottenere il nome generico
  String get genName {
    return genericName;
  }

}