import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/part.dart';
import '../models/part_checkout.dart';
import '../utils/backend_data_provider.dart';
import 'warehouse_form_sheet.dart';

class PartReturnSheet extends StatefulWidget {
  const PartReturnSheet({super.key, required this.part});
  final Part part;

  @override
  State<PartReturnSheet> createState() => _PartReturnSheetState();
}

class _PartReturnSheetState extends State<PartReturnSheet> {
  final _formKey = GlobalKey<FormState>();
  final _quantity = TextEditingController();
  final _notes = TextEditingController();
  List<PartCheckout>? _checkouts;
  PartCheckout? _selected;
  String _condition = 'GOOD';
  String? _error;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _error = null;
      _checkouts = null;
    });
    try {
      final checkouts = await context
          .read<BackendDataProvider>()
          .getOpenPartCheckouts(widget.part.id);
      if (!mounted) return;
      setState(() {
        _checkouts = checkouts;
        _selected = checkouts.firstOrNull;
        _quantity.text = _selected?.remainingQuantity.toString() ?? '';
      });
    } catch (error) {
      if (mounted) setState(() => _error = 'Không tải được lượt mượn: $error');
    }
  }

  Future<void> _save() async {
    if (_saving || !_formKey.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await context.read<BackendDataProvider>().returnPart(
        _selected!.id,
        quantity: double.parse(_quantity.text.trim()),
        conditionStatus: _condition,
        notes: _notes.text.trim(),
      );
      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = 'Trả linh kiện thất bại: $error';
        });
      }
    }
  }

  @override
  void dispose() {
    _quantity.dispose();
    _notes.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_saving,
    child: WarehouseFormSheet(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Trả linh kiện: ${widget.part.name}',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            Expanded(
              child: SingleChildScrollView(
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (_error != null) ...[
                        Text(
                          _error!,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                        if (_checkouts == null)
                          TextButton(
                            onPressed: _load,
                            child: const Text('Thử lại'),
                          ),
                      ] else if (_checkouts == null)
                        const Center(child: CircularProgressIndicator()),
                      if (_checkouts?.isEmpty ?? false)
                        const Text('Không có lượt mượn linh kiện đang mở.'),
                      if (_checkouts?.isNotEmpty ?? false) ...[
                        DropdownButtonFormField<PartCheckout>(
                          initialValue: _selected,
                          isExpanded: true,
                          decoration: const InputDecoration(
                            labelText: 'Lượt mượn cần trả',
                          ),
                          items: _checkouts!
                              .map(
                                (checkout) => DropdownMenuItem(
                                  value: checkout,
                                  child: Text(
                                    '${checkout.takenByName} · ${checkout.locationCode} · Còn ${checkout.remainingQuantity}',
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              )
                              .toList(),
                          onChanged: _saving
                              ? null
                              : (value) => setState(() {
                                  _selected = value;
                                  _quantity.text =
                                      value?.remainingQuantity.toString() ?? '';
                                }),
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _quantity,
                          enabled: !_saving,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          decoration: const InputDecoration(
                            labelText: 'Số lượng trả *',
                          ),
                          validator: (text) {
                            final value = double.tryParse(text?.trim() ?? '');
                            if (value == null ||
                                !value.isFinite ||
                                value < 0.0001) {
                              return 'Nhập số lượng lớn hơn hoặc bằng 0.0001';
                            }
                            if (value > _selected!.remainingQuantity) {
                              return 'Số lượng trả vượt quá số lượng còn mượn';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        DropdownButtonFormField<String>(
                          initialValue: _condition,
                          decoration: const InputDecoration(
                            labelText: 'Tình trạng linh kiện',
                          ),
                          items: const [
                            DropdownMenuItem(
                              value: 'GOOD',
                              child: Text('Còn tốt'),
                            ),
                            DropdownMenuItem(
                              value: 'DAMAGED',
                              child: Text('Hỏng'),
                            ),
                            DropdownMenuItem(
                              value: 'REPLACED',
                              child: Text('Đã thay thế'),
                            ),
                          ],
                          onChanged: _saving
                              ? null
                              : (value) => setState(() => _condition = value!),
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _notes,
                          enabled: !_saving,
                          maxLines: 3,
                          decoration: const InputDecoration(
                            labelText: 'Ghi chú',
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                TextButton(
                  onPressed: _saving ? null : () => Navigator.pop(context),
                  child: const Text('Hủy'),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _saving || _selected == null ? null : _save,
                    child: _saving
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Xác nhận trả'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}
