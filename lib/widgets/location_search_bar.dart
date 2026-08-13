import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/location_search_service.dart';

class LocationSearchBar extends StatefulWidget {
	final Function(SearchResult result) onLocationSelected;

	const LocationSearchBar({
		super.key,
		required this.onLocationSelected,
	});

	@override
	State<LocationSearchBar> createState() => _LocationSearchBarState();
}

class _LocationSearchBarState extends State<LocationSearchBar> {
	final TextEditingController _controller = TextEditingController();
	final FocusNode _focusNode = FocusNode();
	final LocationSearchService _searchService = LocationSearchService();

	List<SearchResult> _results = [];
	bool _isLoading = false;
	bool _showDropdown = false;
	Timer? _debounceTimer;

	@override
	void initState() {
		super.initState();
		_focusNode.addListener(() {
			if (!_focusNode.hasFocus) {
				setState(() {
					_showDropdown = false;
				});
			}
		});
	}

	void _onQueryChanged(String query) {
		_debounceTimer?.cancel();
		if (query.trim().isEmpty) {
			setState(() {
				_results = [];
				_isLoading = false;
				_showDropdown = false;
			});
			return;
		}

		_debounceTimer = Timer(const Duration(milliseconds: 400), () async {
			setState(() {
				_isLoading = true;
				_showDropdown = true;
			});

			try {
				final results = await _searchService.search(query);
				if (!mounted) return;
				setState(() {
					_results = results;
					_isLoading = false;
				});
			} catch (_) {
				if (!mounted) return;
				setState(() {
					_results = [];
					_isLoading = false;
				});
			}
		});
	}

	void _clear() {
		_controller.clear();
		_debounceTimer?.cancel();
		setState(() {
			_results = [];
			_isLoading = false;
			_showDropdown = false;
		});
		_focusNode.unfocus();
	}

	@override
	Widget build(BuildContext context) {
		final theme = Theme.of(context);

		return Column(
			mainAxisSize: MainAxisSize.min,
			children: [
				Card(
					elevation: 4,
					shadowColor: Colors.black.withValues(alpha: 0.15),
					shape: RoundedRectangleBorder(
						borderRadius: BorderRadius.circular(16),
					),
					child: TextField(
						controller: _controller,
						focusNode: _focusNode,
						onChanged: _onQueryChanged,
						textInputAction: TextInputAction.search,
						onSubmitted: (query) => _onQueryChanged(query),
						decoration: InputDecoration(
							hintText: 'Buscar dirección o lugar...',
							hintStyle: TextStyle(
								color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
								fontSize: 14,
							),
							prefixIcon: Icon(
								Icons.search_rounded,
								color: theme.colorScheme.primary,
							),
							suffixIcon: _isLoading
									? Padding(
											padding: const EdgeInsets.all(12.0),
											child: SizedBox(
												width: 18,
												height: 18,
												child: CircularProgressIndicator(
													strokeWidth: 2,
													color: theme.colorScheme.primary,
												),
											),
										)
									: _controller.text.isNotEmpty
											? IconButton(
													icon: const Icon(Icons.close_rounded, size: 20),
													onPressed: _clear,
												)
											: null,
							border: InputBorder.none,
							contentPadding: const EdgeInsets.symmetric(
								horizontal: 16,
								vertical: 14,
							),
						),
					),
				),
				if (_showDropdown && (_results.isNotEmpty || _isLoading))
					Card(
						elevation: 6,
						margin: const EdgeInsets.only(top: 6),
						shape: RoundedRectangleBorder(
							borderRadius: BorderRadius.circular(16),
						),
						child: ConstrainedBox(
							constraints: const BoxConstraints(maxHeight: 240),
							child: _isLoading && _results.isEmpty
									? const Padding(
											padding: EdgeInsets.all(20.0),
											child: Center(
												child: Text(
													'Buscando ubicaciones...',
													style: TextStyle(fontSize: 13),
												),
											),
										)
									: ListView.separated(
											shrinkWrap: true,
											padding: const EdgeInsets.symmetric(vertical: 6),
											itemCount: _results.length,
											separatorBuilder: (context, index) =>
													const Divider(height: 1, indent: 48),
											itemBuilder: (context, index) {
												final result = _results[index];
												return ListTile(
													dense: true,
													leading: Container(
														padding: const EdgeInsets.all(6),
														decoration: BoxDecoration(
															color: theme.colorScheme.primaryContainer,
															shape: BoxShape.circle,
														),
														child: Icon(
															Icons.location_on_rounded,
															size: 18,
															color: theme.colorScheme.onPrimaryContainer,
														),
													),
													title: Text(
														result.name,
														style: const TextStyle(
															fontWeight: FontWeight.bold,
															fontSize: 14,
														),
														maxLines: 1,
														overflow: TextOverflow.ellipsis,
													),
													subtitle: Text(
														result.address,
														style: TextStyle(
															fontSize: 12,
															color: theme.colorScheme.onSurface
																	.withValues(alpha: 0.7),
														),
														maxLines: 2,
														overflow: TextOverflow.ellipsis,
													),
													onTap: () {
														HapticFeedback.selectionClick();
														_controller.text = result.name;
														setState(() {
															_showDropdown = false;
														});
														_focusNode.unfocus();
														widget.onLocationSelected(result);
													},
												);
											},
										),
						),
					),
			],
		);
	}

	@override
	void dispose() {
		_controller.dispose();
		_focusNode.dispose();
		_debounceTimer?.cancel();
		super.dispose();
	}
}
