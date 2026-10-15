import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/app_permission.dart';
import '../utils/auth_provider.dart';
import '../widgets/permission_gate.dart';
import '../models/customer.dart';
import '../models/repair_order.dart';
import '../utils/backend_data_provider.dart';

class CustomerOrderLinkDialog extends StatefulWidget {
  final Customer customer;
  final BackendDataProvider backend;

  const CustomerOrderLinkDialog({
    super.key,
    required this.customer,
    required this.backend,
  });

  @override
  State<CustomerOrderLinkDialog> createState() =>
      _CustomerOrderLinkDialogState();
}

class _CustomerOrderLinkDialogState extends State<CustomerOrderLinkDialog> {
  final _search = TextEditingController();
  final _reason = TextEditingController();
  Timer? _debounce;
  List<RepairOrder> _orders = [];
  RepairOrder? _selected;
  bool _unlinkedOnly = true;
  bool _loading = true;
  bool _saving = false;
  int _page = 0;
  int _totalPages = 0;
  int _request = 0;
  String? _loadError;
  String? _saveError;

  @override
  void initState() {
    super.initState();
    _unlinkedOnly = context.read<AuthProvider>().can(
      AppPermission.assignOrderCustomer,
    );
    _load();
  }

  Future<void> _load() async {
    final request = ++_request;
    setState(() {
      _loading = true;
      _loadError = null;
      _selected = null;
    });
    try {
      final data = await widget.backend.api.get(
        '/api/v1/repair-orders',
        queryParameters: {
          'keyword': _search.text.trim(),
          'page': _page,
          'size': 20,
          'unlinkedOnly': _unlinkedOnly,
        },
      );
      if (!mounted || request != _request) return;
      setState(() {
        _orders = (data['content'] as List)
            .map(
              (json) =>
                  RepairOrder.fromJson(Map<String, dynamic>.from(json as Map)),
            )
            .toList();
        _totalPages = data['totalPages'] as int;
      });
    } catch (error) {
      if (mounted && request == _request) {
        setState(() {
          _orders = [];
          _loadError = error.toString();
        });
      }
    } finally {
      if (mounted && request == _request) setState(() => _loading = false);
    }
  }

  void _searchChanged(String _) {
    _debounce?.cancel();
    _request++;
    setState(() {
      _page = 0;
      _selected = null;
      _orders = [];
      _loading = true;
      _saveError = null;
    });
    _debounce = Timer(const Duration(milliseconds: 300), _load);
  }

  Future<void> _save() async {
    final order = _selected;
    if (!context.read<AuthProvider>().can(
      order?.customerId == null
          ? AppPermission.assignOrderCustomer
          : AppPermission.transferOrderCustomer,
    )) {
      return;
    }
    if (order == null ||
        _reason.text.trim().isEmpty ||
        _saving ||
        !widget.customer.active) {
      return;
    }
    setState(() {
      _saving = true;
      _saveError = null;
    });
    try {
      await widget.backend.linkRepairOrderCustomer(
        order.id,
        customerId: widget.customer.id,
        reason: _reason.text,
        reload: false,
      );
      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      if (mounted) {
        setState(() {
          _saveError = error.toString();
          _saving = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    _reason.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final selected = _selected;
    return PopScope(
      canPop: !_saving,
      child: AlertDialog(
        title: const Text('Gán đơn đã có'),
        content: SizedBox(
          width: 520,
          height: MediaQuery.sizeOf(context).height * .65,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Khách hàng nhận đơn: ${widget.customer.name} (${widget.customer.customerCode})',
                ),
                const SizedBox(height: 12),
                TextField(
                  key: const Key('link-order-search'),
                  controller: _search,
                  enabled: !_saving,
                  decoration: const InputDecoration(
                    labelText: 'Tìm mã đơn, số seri, tên khách, số điện thoại',
                  ),
                  onChanged: _searchChanged,
                ),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Chỉ hiện đơn chưa gán khách hàng'),
                  value: _unlinkedOnly,
                  onChanged: _saving
                      ? null
                      : (value) {
                          _debounce?.cancel();
                          _unlinkedOnly = value ?? true;
                          _page = 0;
                          _saveError = null;
                          _load();
                        },
                ),
                const Text('Chỉ hiển thị đơn trong phạm vi quyền của bạn.'),
                if (_loading)
                  const Center(child: CircularProgressIndicator())
                else if (_loadError != null) ...[
                  Text(
                    _loadError!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                  TextButton(onPressed: _load, child: const Text('Thử lại')),
                ] else if (_orders.isEmpty)
                  const Text('Không tìm thấy đơn phù hợp.')
                else
                  SizedBox(
                    height: 180,
                    child: ListView.builder(
                      itemCount: _orders.length,
                      itemBuilder: (_, index) {
                        final order = _orders[index];
                        final alreadyLinked =
                            order.customerId == widget.customer.id;
                        if (!context.watch<AuthProvider>().can(
                          order.customerId == null
                              ? AppPermission.assignOrderCustomer
                              : AppPermission.transferOrderCustomer,
                        )) {
                          return ListTile(
                            title: Text(
                              '${order.orderNumber} · ${order.deviceName}',
                            ),
                            subtitle: Text(order.customerName),
                          );
                        }
                        return ListTile(
                          enabled: !_saving && !alreadyLinked,
                          leading: Icon(
                            selected?.id == order.id
                                ? Icons.radio_button_checked
                                : Icons.radio_button_unchecked,
                          ),
                          title: Text(
                            '${order.orderNumber} · ${order.deviceName}',
                          ),
                          subtitle: Text(
                            '${order.customerName}${order.customerPhone == null ? '' : ' · ${order.customerPhone}'}\n${alreadyLinked
                                ? 'Đã thuộc khách hàng này'
                                : order.customerId != null
                                ? 'Đã gán khách hàng — chọn để chuyển'
                                : 'Chưa gán hồ sơ khách hàng'}',
                          ),
                          onTap: () => setState(() {
                            _selected = order;
                            _saveError = null;
                          }),
                        );
                      },
                    ),
                  ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    TextButton(
                      onPressed: _saving || _loading || _page == 0
                          ? null
                          : () {
                              _page--;
                              _load();
                            },
                      child: const Text('Trước'),
                    ),
                    Text(
                      'Trang ${_page + 1} / ${_totalPages < 1 ? 1 : _totalPages}',
                    ),
                    TextButton(
                      onPressed: _saving || _loading || _page + 1 >= _totalPages
                          ? null
                          : () {
                              _page++;
                              _load();
                            },
                      child: const Text('Sau'),
                    ),
                  ],
                ),
                if (selected != null) ...[
                  if (selected.customerId != null)
                    const Text('Đơn sẽ được chuyển khỏi khách hàng hiện tại.'),
                  Text(
                    'Tên khách hàng trên đơn sẽ đổi từ “${selected.customerName}” thành “${widget.customer.name}”. Số điện thoại được cập nhật theo hồ sơ nhận đơn.',
                  ),
                ],
                TextField(
                  key: const Key('link-order-reason'),
                  controller: _reason,
                  enabled: !_saving,
                  maxLength: 500,
                  decoration: const InputDecoration(
                    labelText: 'Lý do gán/chuyển đơn *',
                  ),
                  onChanged: (_) => setState(() {}),
                ),
                if (_saveError != null)
                  Text(
                    _saveError!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: _saving ? null : () => Navigator.pop(context),
            child: const Text('Hủy'),
          ),
          PermissionGate(
            permission: selected?.customerId == null
                ? AppPermission.assignOrderCustomer
                : AppPermission.transferOrderCustomer,
            child: FilledButton(
              onPressed:
                  _saving ||
                      _loading ||
                      selected == null ||
                      _reason.text.trim().isEmpty ||
                      !widget.customer.active
                  ? null
                  : _save,
              child: Text(
                _saving
                    ? 'Đang lưu...'
                    : selected?.customerId != null
                    ? 'Xác nhận chuyển đơn'
                    : 'Xác nhận gán đơn',
              ),
            ),
          ),
        ],
      ),
    );
  }
}
