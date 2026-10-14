import 'dart:async';
import 'package:flutter/material.dart';
import '../../models/repair_order.dart';
import '../../utils/api_client.dart';

class RepairOrderPickerDialog extends StatefulWidget {
  const RepairOrderPickerDialog({
    super.key,
    required this.api,
    required this.onSend,
  });
  final ApiClient api;
  final Future<void> Function(RepairOrder) onSend;
  @override
  State<RepairOrderPickerDialog> createState() =>
      _RepairOrderPickerDialogState();
}

class _RepairOrderPickerDialogState extends State<RepairOrderPickerDialog> {
  final _search = TextEditingController();
  Timer? _debounce;
  List<RepairOrder> _orders = [];
  RepairOrder? _selected;
  bool _loading = true;
  bool _sending = false;
  bool _hasMore = false;
  int _page = 0;
  int _request = 0;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({bool more = false}) async {
    final request = ++_request;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final page = more ? _page + 1 : 0;
      final data = await widget.api.get(
        '/api/v1/repair-orders',
        queryParameters: {
          'keyword': _search.text.trim(),
          'page': page,
          'size': 30,
        },
      );
      if (!mounted || request != _request) return;
      final content = data is Map
          ? data['content'] as List? ?? []
          : data as List? ?? [];
      final orders = content.map((json) => RepairOrder.fromJson(json)).toList();
      setState(() {
        _orders = more ? [..._orders, ...orders] : orders;
        if (!more) _selected = null;
        _page = page;
        _hasMore = data is Map && data['last'] is bool
            ? data['last'] == false
            : orders.length == 30;
      });
    } catch (error) {
      if (mounted && request == _request) {
        setState(
          () => _error = 'Không thể tải đơn sửa chữa. Vui lòng thử lại.',
        );
      }
    } finally {
      if (mounted && request == _request) setState(() => _loading = false);
    }
  }

  Future<void> _send() async {
    final order = _selected;
    if (order == null || _sending) return;
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      await widget.onSend(order);
      if (mounted) Navigator.pop(context);
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Không thể gửi thẻ đơn. Vui lòng thử lại.');
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_sending,
    child: AlertDialog(
      title: const Text('Gửi thẻ đơn sửa chữa'),
      content: SizedBox(
        width: 440,
        height: MediaQuery.sizeOf(context).height * .5,
        child: Column(
          children: [
            TextField(
              controller: _search,
              enabled: !_sending,
              decoration: const InputDecoration(
                hintText: 'Tìm mã đơn hoặc tên máy',
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: (_) {
                _request++;
                setState(() {
                  _selected = null;
                  _orders = [];
                  _loading = true;
                  _error = null;
                });
                _debounce?.cancel();
                _debounce = Timer(
                  const Duration(milliseconds: 300),
                  () => _load(),
                );
              },
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(_error!),
              ),
            Expanded(
              child: _loading && _orders.isEmpty
                  ? const Center(child: CircularProgressIndicator())
                  : _orders.isEmpty
                  ? Center(
                      child: Text(
                        _error == null ? 'Không tìm thấy đơn sửa chữa' : '',
                      ),
                    )
                  : ListView.builder(
                      itemCount: _orders.length,
                      itemBuilder: (_, index) {
                        final order = _orders[index];
                        return ListTile(
                          leading: Icon(
                            _selected?.id == order.id
                                ? Icons.radio_button_checked
                                : Icons.radio_button_unchecked,
                          ),
                          onTap: _sending
                              ? null
                              : () => setState(() => _selected = order),
                          title: Text(order.orderNumber),
                          subtitle: Text(
                            '${order.deviceName}\n${order.statusLabel}',
                          ),
                        );
                      },
                    ),
            ),
            if (_loading && _orders.isNotEmpty) const LinearProgressIndicator(),
            if (_error != null && !_sending)
              TextButton(
                onPressed: _loading ? null : () => _load(),
                child: const Text('Tải lại'),
              ),
            if (_hasMore)
              TextButton(
                onPressed: _loading || _sending
                    ? null
                    : () => _load(more: true),
                child: const Text('Tải thêm'),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _sending ? null : () => Navigator.pop(context),
          child: const Text('Hủy'),
        ),
        FilledButton(
          onPressed: _selected == null || _loading || _sending ? null : _send,
          child: Text(_sending ? 'Đang gửi...' : 'Gửi thẻ'),
        ),
      ],
    ),
  );
}
