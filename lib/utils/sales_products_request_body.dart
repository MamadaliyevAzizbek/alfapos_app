/// POST /sales/products so‘rov tanasi — web POS bilan mos filterlar.
Map<String, dynamic> buildSalesProductsRequestBody({
  required int branchId,
  required String searchValue,
  required int offset,
  int rowLimit = 40,
  String? categoryId,
  String? brandId,
}) {
  final cat = categoryId?.trim();
  final br = brandId?.trim();
  final catValue = (cat == null || cat.isEmpty) ? 'all' : cat;
  final brandValue = (br == null || br.isEmpty) ? 'all' : br;
  final catInt = int.tryParse(catValue);
  final brandInt = int.tryParse(brandValue);

  return {
    'orderType': 'sales',
    'currentBranch': branchId,
    'searchValue': searchValue,
    'rowLimit': rowLimit,
    'offset': offset,
    'categoryId': cat ?? '',
    'brandId': br ?? '',
    if (catInt != null) 'category_id': catInt,
    if (brandInt != null) 'brand_id': brandInt,
    if (catInt != null) 'category': catInt,
    if (brandInt != null) 'brand': brandInt,
    'filtersData': [
      {'key': 'status', 'value': 'all'},
      {'key': 'category', 'value': catValue},
      {'key': 'brand', 'value': brandValue},
    ],
  };
}
