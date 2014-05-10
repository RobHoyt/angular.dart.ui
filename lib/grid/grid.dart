// Copyright (C) 2013 - 2014 Angular Dart UI authors. Please see AUTHORS.md.
// https://github.com/akserg/angular.dart.ui
// All rights reserved.  Please seegriddropdown_toggle;

import 'dart:html' as dom;
import 'dart:async' as async;
import "package:angular/angular.dart";
import "package:angular/core_dom/module_internal.dart";
import "package:angular_ui/utils/timeout.dart";
import "package:angular_ui/utils/utils.dart";

/**
 * Grid Module.
 */
class GridModule extends Module {
  GridModule() {
    type(Grid);
  }
}

typedef OnDataRequired(GridOptions options);

class GridColumnOptions {
  String fieldName;
  String displayName;
  String displayAlign = 'left';
  String displayFormat;
  bool enableSorting = true;
  bool enableFiltering = true;
  String cellWidth;
  String cellHeight;
}

class GridOptions {
//  List items = [];
  List selectedItems = [];
  String filterBy;
  Map filterByFields = {};
  String orderBy;
  bool orderByReverse = false;
  int pageItems = 0;
  int currentPage = 0;
  int totalItems = 0;
  bool enableFiltering = false;
  bool enableSorting = false;
  bool enableSelections = false;
  bool enableMultiRowSelections = false;
  OnDataRequired onDataRequired;
  int onDataRequiredDelay = 1000;
  List<GridColumnOptions> gridColumnDefs = [];
}

class PagerOptions {
  bool isPaged;
  int totalItemsCount;
  int startItemIndex;
  int endItemIndex;
  bool pageCanGoBack;
  bool pageCanGoForward;
}

@Decorator(selector:"table[tr-ng-grid]")
class Grid {
  
  List _items = [];
  @NgTwoWay('items')
  set items(value) {
    _items = value == null ? [] : value;
    if (gridOptions.gridColumnDefs.length == 0 && _items.length > 0 && _items.first is Map) {
      Map item = items.first;
      for (var key in item.keys) {
        GridColumnOptions colDef = new GridColumnOptions()
        ..fieldName = key
        ..displayName = key;
        gridOptions.gridColumnDefs.add(colDef);
      }
      _update();
    }
    _render();
  }
  List get items => _items;
  
  dom.TableElement _grid;
  dom.TableSectionElement _head;
  dom.TableSectionElement _body;
  
  Scope _scope;
  NodeAttrs _attrs;
  Timeout _timeout;
  async.Completer _dataRequestPromise;
  FieldGetterFactory _fieldGetterFactory;
  
  GridOptions gridOptions;
  PagerOptions pagerOptions;
  
  Grid(dom.Element gridEl, this._scope, this._attrs, this._timeout, this._fieldGetterFactory) {
    _grid = gridEl as dom.TableElement;
    _grid.classes.add('tr-ng-grid table table-bordered table-hover');
    //
    _scope.context['gridOptions'] = gridOptions = new GridOptions();
    _scope.context['pagerOptions'] = pagerOptions = new PagerOptions();
    //
    _scope.watch('[gridOptions.currentPage, items.length, gridOptions.totalItems, gridOptions.pageItems]', (value, old){
      _updatePager();
    }, collection:true);
    //
    _parseAttributes();
    _parse();
    _update();
    _updatePager();
    _render();
  }

  _parseAttributes() {
    
  }
  
  _parse() {
    
  }
  
  //*******
  // Update
  //*******
  
  // Update internal element with GridOptions
  _update() {
    // Remove all children of grid before rendering
    _grid.children.clear();
    // Create header
    _createHead();
    // Create Footer
    _createFooter();
    // Create Body
    _createBody();
  }
  
  /**
   * Create Head element and all columns based on [GridOptions].gridColumnDefs
   * of [GridColumnOptions].
   */
  _createHead() {
    _head = _grid.createTHead();
    dom.TableRowElement row = _head.addRow()
    ..attributes['tr-ng-grid-header'] = '';
//    <th field-name="id" class="ng-scope">
    gridOptions.gridColumnDefs.forEach((GridColumnOptions colDef) {
      dom.TableCellElement th = row.addCell()
      ..attributes['field-name'] = colDef.fieldName;
      //
//      <div class="tr-ng-cell ng-scope">
      dom.DivElement cell = new dom.DivElement()
      ..classes.add('tr-ng-cell');
      th.append(cell);
      //
//        <div>
      dom.DivElement sortWrapper = new dom.DivElement();
      cell.append(sortWrapper);
      //
//          <div class="tr-ng-title">Id</div>
      dom.DivElement title = new dom.DivElement()
      ..text = colDef.displayName;
      sortWrapper.append(title);
      //
//          <div ng-show="currentGridColumnDef.enableSorting" ng-click="toggleSorting(currentGridColumnDef.fieldName)" title="Sort" class="tr-ng-sort" tr-ng-grid-column-sort="">
      if (colDef.enableSorting) {
        dom.DivElement sort = new dom.DivElement()
        ..title = "Sort"
        ..classes.add("tr-ng-sort")
        ..attributes['tr-ng-grid-column-sort'] = ''
        ..onClick.listen((dom.MouseEvent evt){
          toggleSorting(colDef.fieldName);
        });
        sortWrapper.append(sort);
        //
//            <div ng-class="{'tr-ng-sort-active':gridOptions.orderBy==currentGridColumnDef.fieldName,'tr-ng-sort-inactive':gridOptions.orderBy!=currentGridColumnDef.fieldName,'tr-ng-sort-reverse':gridOptions.orderByReverse}" class="tr-ng-sort-inactive"></div>
        dom.DivElement icon = new dom.DivElement()
        ..classes.add('tr-ng-sort-inactive');
        _scope.watch('gridOptions.orderBy', (value, old) {
          if (value == colDef.fieldName) {
            icon.classes.add('tr-ng-sort-active');
            icon.classes.remove('tr-ng-sort-inactive');
          } else {
            icon.classes.add('tr-ng-sort-inactive');
            icon.classes.remove('tr-ng-sort-active');
          }
        });
        _scope.watch('gridOptions.orderByReverse', (value, old) {
          if (value) {
            icon.classes.add('tr-ng-sort-reverse');
          } else {
            icon.classes.remove('tr-ng-sort-reverse');
          }
        });
        sort.append(icon);
      }
      //
//        <div ng-show="currentGridColumnDef.enableFiltering" class="tr-ng-column-filter" tr-ng-grid-column-filter="">
      if (colDef.enableFiltering) {
        dom.DivElement filter = new dom.DivElement()
        ..classes.add('tr-ng-column-filter')
        ..attributes['tr-ng-grid-column-filter'] = '';
        cell.append(filter);
        //
//          <div class=""><input class="form-control input-sm ng-pristine ng-valid" type="text" ng-model="filter"></div>
        dom.DivElement inputWrapper = new dom.DivElement();
        filter.append(inputWrapper);
        //
        dom.InputElement input = new dom.InputElement()
        ..classes.add('form-control input-sm ng-pristine ng-valid')
        ..type = 'text'
        ..onChange.listen((dom.Event evt) {
            setFilter(colDef.fieldName, (evt.target as dom.InputElement).text);
        });
        inputWrapper.append(input);
      }
    });
  }
  
  /**
   * Create Foot element, global search and pager based on 
   * [GridOptions].totalItemsCount
   */
  _createFooter() {
//    <tfoot>
    dom.TableSectionElement foot = _grid.createTFoot();
//      <tr>
    dom.TableRowElement row = foot.addRow();
//        <td colspan="999">
    dom.TableCellElement cell = row.addCell()
    ..colSpan = gridOptions.gridColumnDefs.length;
//          <div class="tr-ng-grid-footer form-inline" tr-ng-grid-footer="">
    dom.DivElement wrapper = new dom.DivElement()
    ..classes.add('tr-ng-grid-footer form-inline')
    ..attributes['tr-ng-grid-footer'];
    cell.append(wrapper);
//            <span ng-show="gridOptions.enableFiltering" class="pull-left form-group ng-scope" tr-ng-grid-global-filter="">
    if (gridOptions.enableFiltering) {
      dom.SpanElement filter = new dom.SpanElement()
      ..classes.add('pull-left form-group ng-scope')
      ..attributes['tr-ng-grid-global-filter'];
      wrapper.append(filter);
//              <input class="form-control ng-pristine ng-valid" type="text" ng-model="gridOptions.filterBy" placeholder="Search">
      dom.InputElement input = new dom.InputElement()
      ..classes.add('form-control ng-pristine ng-valid')
      ..type = 'test'
      ..placeholder = 'Search'
      ..onChange.listen((dom.Event evt) {
        print('Search ${(evt.target as dom.InputElement).text}');
      });
      filter.append(input);
//            </span>
    }
//            <span class="pull-right form-group ng-scope" tr-ng-grid-pager="">
    dom.SpanElement pager = new dom.SpanElement()
    ..classes.add('pull-right form-group ng-scope')
    ..attributes['tr-ng-grid-pager'];
    wrapper.append(pager);
//              <ul class="pagination">
    dom.UListElement pagination = new dom.UListElement()
    ..classes.add('pagination');
    pager.append(pagination);
//                <li><a href="#" ng-show="pageCanGoBack" ng-click="navigatePrevPage($event)" title="Previous Page" class="ng-hide">â‡</a></li>
    dom.LIElement prev = new dom.LIElement();
    pagination.append(prev);
    dom.AnchorElement prevIcon = new dom.AnchorElement()
    ..href = '#'
    ..title = 'Previous Page'
    ..classes.add('ng-hide')
    ..text = '&lArr'
    ..onClick.listen((dom.MouseEvent evt) {
      navigatePrevPage(evt);
    });
    _scope.watch('pagerOptions.pageCanGoBack', (value, old) {
      if (value) {
        prevIcon.classes.remove("ng-hide");
      } else {
        prevIcon.classes.add("ng-hide");
      }
    });
    prev.append(prevIcon);
//                <li class="disabled" style="white-space: nowrap;">
    dom.LIElement display = new dom.LIElement()
    ..classes.add('disabled')
    ..style.whiteSpace = 'nowrap';
    pagination.append(display);
//                  <span ng-hide="totalItemsCount" class="ng-hide">No items to display</span>
    dom.SpanElement iemsToDisplay = new dom.SpanElement()
    ..classes.add('ng-hide')
    ..text = 'No items to display';
    _scope.watch('pagerOptions.totalItemsCount', (value, old) {
      if (value == 0) {
        iemsToDisplay.text = 'No items to display';
      } else {
        iemsToDisplay.text = '${_scope.context["pagerOptions.startItemIndex"] + 1} - ${_scope.context["pagerOptions.endItemIndex"] + 1} displayed, ${_scope.context["pagerOptions.totalItemsCount"]} in count // ${gridOptions.currentPage}';
      }
    });
    display.append(iemsToDisplay);
//                </li>
//                <li><a href="#" ng-show="pageCanGoForward" ng-click="navigateNextPage($event)" title="Next Page" class="ng-hide">â‡’</a></li>
    dom.LIElement next = new dom.LIElement();
    pagination.append(next);
    dom.AnchorElement nextIcon = new dom.AnchorElement()
    ..href = '#'
    ..title = 'Next Page'
    ..classes.add('ng-hide')
    ..text = '&rArr;'
    ..onClick.listen((dom.MouseEvent evt) {
      navigateNextPage(evt);
    });
    _scope.watch('pagerOptions.pageCanGoForward', (value, old) {
      if (toBool(value)) {
        nextIcon.classes.remove("ng-hide");
      } else {
        nextIcon.classes.add("ng-hide");
      }
    });
    next.append(nextIcon);
//                <li></li>
//              </ul>
//            </span>
//          </div>
//        </td>
//      </tr>
//    </tfoot>
  }
  
  _createBody() {
//    <tbody tr-ng-grid-body="" class="ng-scope"><!-- ngRepeat: gridItem in gridOptions.items | filter:gridOptions.filterBy | filter:gridOptions.filterByFields | orderBy:gridOptions.orderBy:gridOptions.orderByReverse | paging:gridOptions -->
    _body = _grid.createTBody();
  }
  
  //**********
  // Rendering
  //**********
  
  // Render data based in column information
  _render() {
    // Clear gird body before render
    _body.children.clear();
    //
    items.forEach((item) {
//      <tr 
      //ng-repeat="gridItem in gridOptions.items | filter:gridOptions.filterBy | filter:gridOptions.filterByFields | orderBy:gridOptions.orderBy:gridOptions.orderByReverse | paging:gridOptions" ng-click="toggleItemSelection(gridItem)" 
      //ng-class="{'active':gridOptions.selectedItems.indexOf(gridItem)>=0}" tr-ng-grid-row-page-item-index="0" class="ng-scope">
      dom.TableRowElement row = _body.addRow();
//      ..attributes['tr-ng-grid-row-page-item-index'] = '0';
      gridOptions.gridColumnDefs.forEach((GridColumnOptions colDef) {
        
        var val;
        if (item is Map) {
          val = item[colDef.fieldName];
        } else if (item is List) {
          val = item.toString();
        } else {
          Function itemGetter = _fieldGetterFactory.getter(item, colDef.fieldName);
          val = itemGetter(item);
        }
        
        val = val == null ? '' : val.toString();
        
//        <td><div class="tr-ng-cell ng-binding" field-name="id">01</div></td>
        dom.TableCellElement cell = row.addCell();
        dom.DivElement data = new dom.DivElement()
        ..classes.add('tr-ng-cell')
        ..attributes['field-name'] = colDef.fieldName
        ..text = val;
        cell.append(data);
      });
    });
  }

  //******
  // Logic
  //******
  
  toggleSorting(String propertyName) {
    if (gridOptions.orderBy != propertyName) {
      // the column has changed
      gridOptions.orderBy = propertyName;
    } else {
      // the sort direction has changed
      gridOptions.orderByReverse = !gridOptions.orderByReverse;
    }
    
    _render();
  }
  
  setFilter(String propertyName, String filter) {
    if (filter == null) {
      if (gridOptions.filterByFields.containsKey(propertyName)) {
        gridOptions.filterByFields.remove(propertyName);
      }
    } else {
      gridOptions.filterByFields[propertyName] = filter;
    }

    _render();
  }
  
  navigatePrevPage(dom.Event event) {
    gridOptions.currentPage = gridOptions.currentPage - 1;
    event.preventDefault();
    event.stopPropagation();
    
    _render();
  }
  
  navigateNextPage(dom.Event event) {
    gridOptions.currentPage = gridOptions.currentPage + 1;
    event.preventDefault();
    event.stopPropagation();
    
    _render();
  }
  
  _updatePager() {
    pagerOptions.isPaged = gridOptions.pageItems > 0;

    // do not set scope.gridOptions.totalItems, it might be set from the outside
    pagerOptions.totalItemsCount = gridOptions.totalItems != null ? gridOptions.totalItems : items != null ? items.length : 0;

    pagerOptions.startItemIndex = pagerOptions.isPaged ? gridOptions.pageItems * gridOptions.currentPage : 0;
    pagerOptions.endItemIndex = pagerOptions.isPaged ? pagerOptions.startItemIndex + gridOptions.pageItems-1 : pagerOptions.totalItemsCount - 1;
    if (pagerOptions.endItemIndex >= pagerOptions.totalItemsCount) {
      pagerOptions.endItemIndex = pagerOptions.totalItemsCount - 1;
    }
    if (pagerOptions.endItemIndex < pagerOptions.startItemIndex) {
      pagerOptions.endItemIndex = pagerOptions.startItemIndex;
    }

    pagerOptions.pageCanGoBack = pagerOptions.isPaged && gridOptions.currentPage > 0;
    pagerOptions.pageCanGoForward = pagerOptions.isPaged && pagerOptions.endItemIndex < pagerOptions.totalItemsCount - 1;
  }
}