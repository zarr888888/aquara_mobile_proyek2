import 'package:flutter/material.dart';
import '../models/pasar_item.dart';

class PasarOptionalFields extends StatelessWidget {
  const PasarOptionalFields({
    super.key,
    required this.stock,
    required this.category,
    required this.saleType,
    required this.onCategory,
    required this.onSaleType,
    this.errors = const {},
  });
  final TextEditingController stock;
  final String? category, saleType;
  final ValueChanged<String?> onCategory, onSaleType;
  final Map<String, List<String>> errors;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      const SizedBox(height: 15),
      TextFormField(
        controller: stock,
        keyboardType: TextInputType.number,
        decoration: InputDecoration(
          labelText: 'Stok (opsional)',
          helperText: 'Bilangan bulat, tanpa separator.',
          helperMaxLines: 2,
          errorText: errors['stok']?.join(' '),
          border: const OutlineInputBorder(),
        ),
        validator: (value) => pasarNumberError(value, optional: true),
      ),
      const SizedBox(height: 15),
      DropdownButtonFormField<String>(
        initialValue: category,
        isExpanded: true,
        decoration: InputDecoration(
          labelText: 'Kategori (opsional)',
          errorText: errors['kategori']?.join(' '),
          border: const OutlineInputBorder(),
        ),
        items: [
          const DropdownMenuItem(
            value: null,
            child: Text('Tidak diubah / default'),
          ),
          ...pasarCategories.map(
            (v) => DropdownMenuItem(value: v, child: Text(v)),
          ),
        ],
        onChanged: onCategory,
      ),
      const SizedBox(height: 15),
      DropdownButtonFormField<String>(
        initialValue: saleType,
        isExpanded: true,
        decoration: InputDecoration(
          labelText: 'Tipe penjualan (opsional)',
          errorText: errors['tipe_penjualan']?.join(' '),
          border: const OutlineInputBorder(),
        ),
        items: [
          const DropdownMenuItem(
            value: null,
            child: Text('Tidak diubah / default'),
          ),
          ...pasarSaleTypes.map(
            (v) => DropdownMenuItem(value: v, child: Text(v)),
          ),
        ],
        onChanged: onSaleType,
      ),
    ],
  );
}
