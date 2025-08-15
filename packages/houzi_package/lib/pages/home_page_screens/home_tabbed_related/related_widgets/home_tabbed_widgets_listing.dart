import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:houzi_package/files/hooks_files/hooks_configurations.dart';
import 'package:houzi_package/models/api/api_response.dart';
import 'package:houzi_package/models/blog_models/blog_articles_data.dart';
import 'package:houzi_package/models/home_related/terms_with_icon.dart';
import 'package:houzi_package/pages/home_screen_drawer_menu_pages/all_blogs.dart';
import 'package:houzi_package/providers/state_providers/locale_provider.dart';
import 'package:houzi_package/files/app_preferences/app_preferences.dart';
import 'package:houzi_package/files/theme_service_files/theme_storage_manager.dart';
import 'package:houzi_package/pages/home_screen_drawer_menu_pages/all_agency.dart';
import 'package:houzi_package/pages/home_screen_drawer_menu_pages/all_agents.dart';
import 'package:houzi_package/pages/search_result.dart';
import 'package:houzi_package/widgets/blogs_related/blogs_listing_widget.dart';
import 'package:houzi_package/widgets/dynamic_widgets/terms_with_icons_widget.dart';
import 'package:houzi_package/widgets/generic_text_widget.dart';
import 'package:houzi_package/widgets/no_result_error_widget.dart';
import 'package:houzi_package/widgets/partners_widget/partner_widget.dart';
import 'package:houzi_package/widgets/type_status_row_widget.dart';
import 'package:provider/provider.dart';

import 'package:houzi_package/api_management/api_handlers/api_manager.dart';
import 'package:houzi_package/common/constants.dart';
import 'package:houzi_package/files/generic_methods/general_notifier.dart';
import 'package:houzi_package/files/generic_methods/utility_methods.dart';
import 'package:houzi_package/files/hive_storage_files/hive_storage_manager.dart';
import 'package:houzi_package/pages/home_page_screens/parent_home_related/home_screen_widgets/home_screen_properties_related_widgets/explore_properties_widget.dart';
import 'package:houzi_package/pages/home_page_screens/parent_home_related/home_screen_widgets/home_screen_properties_related_widgets/latest_featured_properties_widget/properties_carousel_list_widget.dart';
import 'package:houzi_package/pages/home_page_screens/parent_home_related/home_screen_widgets/home_screen_realtors_related_widgets/home_screen_realtors_list_widget.dart';
import 'package:houzi_package/pages/home_page_screens/parent_home_related/home_screen_widgets/home_screen_recent_searches_widget/home_screen_recent_searches_widget.dart';

typedef HomeTabbedListingsWidgetListener = void Function(bool errorWhileLoading, bool dataLoadingComplete);

class HomeTabbedListingsWidget extends StatefulWidget {
  final homeScreenData;
  final bool refresh;
  final Map selectedItem;
  final HomeTabbedListingsWidgetListener? homeTabbedListingsWidgetListener;

  const HomeTabbedListingsWidget({
    super.key,
    this.homeScreenData,
    this.refresh = false,
    required this.selectedItem,
    this.homeTabbedListingsWidgetListener,
  });

  @override
  State<HomeTabbedListingsWidget> createState() => _HomeScreenListingsWidgetState();
}

class _HomeScreenListingsWidgetState extends State<HomeTabbedListingsWidget>  with AutomaticKeepAliveClientMixin<HomeTabbedListingsWidget>  {

  int page = 1;

  String arrowDirection = " >";

  NativeAd? _nativeAd;

  bool isDataLoaded = false;
  bool noDataReceived = false;
  bool _isNativeAdLoaded = false;

  bool isPageFreeForLoading = true;
  bool permissionGranted = false;

  List<dynamic> homeScreenList = [];

  Map homeConfigMap = {};
  Map<String, dynamic> setRouteRelatedDataMap = {};

  VoidCallback? generalNotifierLister;

  Future<List<dynamic>>? _futureHomeScreenList;

  final ApiManager _apiManager = ApiManager();

  Widget? _placeHolderWidget;

  List<TermsWithIcon> _termsWithIconList = [];

  @override
  void initState() {
    super.initState();

    generalNotifierLister = () {
      if (GeneralNotifier().change == GeneralNotifier.CITY_DATA_UPDATE) {
        if(homeConfigMap[sectionTypeKey] == allPropertyKey &&
            homeConfigMap[subTypeKey] == propertyCityDataType){

          Map<String, dynamic> map = HiveStorageManager.readSelectedCityInfo();
          String cityId = UtilityMethods.valueForKeyOrEmpty(map, CITY_ID);
          String city = UtilityMethods.valueForKeyOrEmpty(map, CITY);

          if (homeConfigMap[subTypeValueCityKey] != cityId) {
            setState(() {
              homeScreenList = [];
              isDataLoaded = false;
              noDataReceived = false;

              homeConfigMap[subTypeValueCityKey] = cityId;

              homeConfigMap[titleKey] = UtilityMethods.titleForSectionBasedOnCitySelection(homeConfigMap, city);
            });

            loadData();
          }
        }
        else if(homeConfigMap[sectionTypeKey] == propertyKey &&
            UtilityMethods.listDependsOnUserSelection(homeConfigMap)){

          Map<String, dynamic> map = HiveStorageManager.readSelectedCityInfo();
          String cityId = UtilityMethods.valueForKeyOrEmpty(map, CITY_ID);

          setState(() {
            if(homeConfigMap[subTypeValueCityKey] != cityId) {
              homeScreenList = [];
              isDataLoaded = false;
              noDataReceived = false;
              homeConfigMap[subTypeValueCityKey] = cityId;
              String city = UtilityMethods.valueForKeyOrEmpty(map, CITY);
              homeConfigMap[titleKey] =
                  UtilityMethods.titleForSectionBasedOnCitySelection(homeConfigMap, city);
            }
          });

          loadData();
        }

      } else if(GeneralNotifier().change == GeneralNotifier.RECENT_DATA_UPDATE &&
          homeConfigMap[sectionTypeKey] == recentSearchKey){
        setState(() {
          homeScreenList.clear();
          List tempList = HiveStorageManager.readRecentSearchesInfo() ?? [];
          homeScreenList.addAll(tempList);
          setState(() {
            isDataLoaded = true;
          });
        });
      } else if(GeneralNotifier().change == GeneralNotifier.TOUCH_BASE_DATA_LOADED &&
          homeConfigMap[sectionTypeKey] != adKey
          && homeConfigMap[sectionTypeKey] != recentSearchKey
          && homeConfigMap[sectionTypeKey] != PLACE_HOLDER_SECTION_TYPE
          && mapEquals(widget.selectedItem, homeConfigMap
          )){
          // widget.selectedItem == homeConfigMap[sectionTypeKey]){
        if(mounted){
          setState(() {
            loadData();
            // widget.refresh = false;
          });
        }
      }
    };

    GeneralNotifier().addListener(generalNotifierLister!);
  }

  @override
  void dispose() {
    super.dispose();

    if(_nativeAd != null){
      _nativeAd!.dispose();
    }
    homeScreenList = [];
    homeConfigMap = {};
    if (generalNotifierLister != null) {
      GeneralNotifier().removeListener(generalNotifierLister!);
    }
  }

  setUpNativeAd() {
    print("CALLING ADS");
    String themeMode = ThemeStorageManager.readData(THEME_MODE_INFO) ?? LIGHT_THEME_MODE;
    bool isDarkMode = false;
    if (themeMode == DARK_THEME_MODE) {
      isDarkMode = true;
    }
    _nativeAd = NativeAd(
      customOptions: {"isDarkMode": isDarkMode},
      adUnitId: Platform.isAndroid ? ANDROID_NATIVE_AD_ID : IOS_NATIVE_AD_ID,
      factoryId: 'homeNativeAd',
      request: const AdRequest(),
      listener: NativeAdListener(
        onAdLoaded: (_) {
          setState(() {
            _isNativeAdLoaded = true;
          });
        },
        onAdFailedToLoad: (ad, error) {
          ad.dispose();
          if (kDebugMode) {
            print(
              'Ad load failed (code=${error.code} message=${error.message})',
            );
          }
        },
      ),
    );

    _nativeAd!.load();
  }

  loadData() {
    // print("Item Section Type: ${widget.homeScreenData[sectionTypeKey]}");
    _futureHomeScreenList = fetchRelatedList(context, page);
    _futureHomeScreenList!.then((value) {
      if (value == null || value.isEmpty) {
        noDataReceived = true;
        widget.homeTabbedListingsWidgetListener!(false, true);
        isPageFreeForLoading = true;
      } else {
        if(value[0].runtimeType == Response){
          // print("Generic Home Listing (Error Code): ${value[0].statusCode}");
          // print("Generic Home Listing (Error Msg): ${value[0].statusMessage}");
          noDataReceived = true;
          widget.homeTabbedListingsWidgetListener!(true, true);
          isPageFreeForLoading = true;
        }else{
          homeScreenList = value;
          isDataLoaded = true;
          widget.homeTabbedListingsWidgetListener!(false, true);
          isPageFreeForLoading = true;
          noDataReceived = false;
        }
      }

      if(mounted){
        setState(() {});
      }

      return null;
    });
  }

  Future<List<dynamic>> fetchRelatedList(BuildContext context, int page) async {
    List<dynamic> tempList = [];
    ApiResponse<List> response;
    setRouteRelatedDataMap = {};

    if (homeConfigMap[showNearbyKey]) {
      permissionGranted = await UtilityMethods.locationPermissionsHandling(permissionGranted);
    }
    try {
      /// Fetch featured properties
      if (homeConfigMap[sectionTypeKey] == featuredPropertyKey) {
        ApiResponse<List> response = await _apiManager.fetchFeaturedArticles(page: page);
        if (response.success && response.internet) {
          tempList = response.result;
        }
      }

      /// Fetch All_properties (old)
      else if (homeConfigMap[sectionTypeKey] == allPropertyKey &&
          homeConfigMap[subTypeKey] != propertyCityDataType) {
        String key = UtilityMethods.getSearchKey(homeConfigMap[subTypeKey]);
        String value = homeConfigMap[subTypeValueKey];
        Map<String, dynamic> dataMap = {};
        if(value != allString && value.isNotEmpty){
          dataMap = {key: value};
        }
        ApiResponse<List> response = await _apiManager.fetchFilteredArticles(params: dataMap);
        if (response.success && response.internet) {
          List<dynamic> filteredArticlesList = response.result;

          if (response.success && response.internet) {
            tempList.addAll(filteredArticlesList);
          }
        }
      }

      /// Fetch latest and city selected properties (old)
      else if (homeConfigMap[sectionTypeKey] == allPropertyKey &&
          homeConfigMap[subTypeKey] == propertyCityDataType) {
        Map<String, dynamic> map = HiveStorageManager.readSelectedCityInfo();
        String city = UtilityMethods.valueForKeyOrEmpty(map, CITY);
        String cityId = UtilityMethods.valueForKeyOrEmpty(map, CITY_ID);
        homeConfigMap[titleKey] = UtilityMethods.titleForSectionBasedOnCitySelection(homeConfigMap, city);
        if (city.isNotEmpty) {
          homeConfigMap[subTypeValueKey] = cityId;
        }
        if (homeConfigMap[subTypeValueKey] == userSelectedString || homeConfigMap[subTypeValueKey] == ""
            || homeConfigMap[subTypeValueKey] == allString) {
          ApiResponse<List> response = await _apiManager.fetchLatestArticles(page: page);
          if (response.success && response.internet) {
            tempList = response.result;
          }
        } else {
          int id = int.parse(homeConfigMap[subTypeValueKey]);
          ApiResponse<List> response = await _apiManager.fetchListingsByCity(id, page, 16);
          if (response.success && response.internet) {
            tempList = response.result;
          }
        }
      }

      /// Fetch Properties
      else if (homeConfigMap[sectionTypeKey] == propertyKey) {
        Map<String, dynamic> dataMap = {};

        if (UtilityMethods.listDependsOnUserSelection(homeConfigMap)) {
          Map<String, dynamic> map = HiveStorageManager.readSelectedCityInfo();
          String locationName = UtilityMethods.locationDependantSectionName(homeConfigMap, map);
          homeConfigMap[titleKey] = UtilityMethods.titleForSectionBasedOnCitySelection(homeConfigMap, locationName);

          String country = UtilityMethods.valueForKeyOrEmpty(map, PROPERTY_COUNTRY);
          String state = UtilityMethods.valueForKeyOrEmpty(map, PROPERTY_STATE);
          String city = UtilityMethods.valueForKeyOrEmpty(map, CITY);
          String area = UtilityMethods.valueForKeyOrEmpty(map, PROPERTY_AREA);

          String countrySlug = UtilityMethods.valueForKeyOrEmpty(map, PROPERTY_COUNTRY_SLUG);
          String stateSlug = UtilityMethods.valueForKeyOrEmpty(map, PROPERTY_STATE_SLUG);
          String citySlug = UtilityMethods.valueForKeyOrEmpty(map, CITY_SLUG);
          String areaSlug = UtilityMethods.valueForKeyOrEmpty(map, PROPERTY_AREA_SLUG);

          setRouteRelatedDataMap.clear();
          if (map.isNotEmpty && locationName.isNotEmpty && locationName != 'please_select') {
            List subTypeList = UtilityMethods.listForKeyOrEmpty(homeConfigMap, subTypeListKey);

            if (areaSlug.isNotEmpty) {
              setRouteRelatedDataMap[PROPERTY_AREA_SLUG] = [areaSlug];
              setRouteRelatedDataMap[PROPERTY_AREA] = [area];
            }
            if (citySlug.isNotEmpty ) {
              setRouteRelatedDataMap[CITY_SLUG] = [citySlug];
              setRouteRelatedDataMap[CITY] = [city];
            }
            if (stateSlug.isNotEmpty) {
              setRouteRelatedDataMap[PROPERTY_STATE_SLUG] = [stateSlug];
              setRouteRelatedDataMap[PROPERTY_STATE] = [state];
            }
            if (countrySlug.isNotEmpty) {
              setRouteRelatedDataMap[PROPERTY_COUNTRY_SLUG] = [countrySlug];
              setRouteRelatedDataMap[PROPERTY_COUNTRY] = [country];
            }

            if ( homeConfigMap[subTypeKey] == propertyCountryDataType || subTypeList.contains(propertyCountryDataType)) {
              if (countrySlug.isNotEmpty) {
                dataMap[SEARCH_RESULTS_COUNTRY] = countrySlug;
              }
            }
            if (homeConfigMap[subTypeKey] == propertyStateDataType || subTypeList.contains(propertyStateDataType)) {

              if (stateSlug.isNotEmpty && stateSlug.toLowerCase() != "all") {
                dataMap.remove(SEARCH_RESULTS_COUNTRY);
                dataMap[SEARCH_RESULTS_STATE] = stateSlug;
              } else {
                if (countrySlug.isNotEmpty && countrySlug.toLowerCase() != 'all') {
                  dataMap[SEARCH_RESULTS_COUNTRY] = countrySlug;
                }
              }
            }
            if (homeConfigMap[subTypeKey] == propertyCityDataType || subTypeList.contains(propertyCityDataType)) {

              if (citySlug.isNotEmpty && citySlug.toLowerCase() != "all") {
                dataMap.remove(SEARCH_RESULTS_STATE);
                dataMap.remove(SEARCH_RESULTS_COUNTRY);
                dataMap[SEARCH_RESULTS_LOCATION] = citySlug;
              } else {

                if (stateSlug.isNotEmpty && stateSlug.toLowerCase() != "all") {
                  dataMap[SEARCH_RESULTS_STATE] = stateSlug;
                } else if (countrySlug.isNotEmpty && countrySlug.toLowerCase() != 'all') {
                  dataMap[SEARCH_RESULTS_COUNTRY] = countrySlug;
                }
              }
            }

            if (homeConfigMap[subTypeKey] == propertyAreaDataType ||  subTypeList.contains(propertyAreaDataType)) {

              if (areaSlug.isNotEmpty && areaSlug.toLowerCase() != "all") {
                dataMap.remove(SEARCH_RESULTS_LOCATION);
                dataMap.remove(SEARCH_RESULTS_STATE);
                dataMap.remove(SEARCH_RESULTS_COUNTRY);

                dataMap[SEARCH_RESULTS_AREA] = areaSlug;
              } else {

                if (citySlug.isNotEmpty && citySlug.toLowerCase() != "all") {
                  dataMap[SEARCH_RESULTS_LOCATION] = citySlug;
                } else if (stateSlug.isNotEmpty && stateSlug.toLowerCase() != "all") {
                  dataMap[SEARCH_RESULTS_STATE] = stateSlug;
                } else if (countrySlug.isNotEmpty && countrySlug.toLowerCase() != 'all') {
                  dataMap[SEARCH_RESULTS_COUNTRY] = countrySlug;
                }
              }
            }

          } else {
            setRouteRelatedDataMap[CITY] = allCapString;
          }
        }

        if(homeConfigMap.containsKey(searchApiMapKey) && homeConfigMap.containsKey(searchRouteMapKey) &&
            (homeConfigMap[searchApiMapKey] != null) && (homeConfigMap[searchRouteMapKey] != null)){
          if (!UtilityMethods.listDependsOnUserSelection(homeConfigMap)) {
            dataMap.addAll(homeConfigMap[searchApiMapKey]);
            setRouteRelatedDataMap.addAll(homeConfigMap[searchRouteMapKey]);
          }
        }
        else if(homeConfigMap.containsKey(subTypeListKey) && homeConfigMap.containsKey(subTypeValueListKey) &&
            (homeConfigMap[subTypeListKey] != null && homeConfigMap[subTypeListKey].isNotEmpty) &&
            (homeConfigMap[subTypeValueListKey] != null && homeConfigMap[subTypeValueListKey].isNotEmpty)){
          List subTypeList = homeConfigMap[subTypeListKey];
          List subTypeValueList = homeConfigMap[subTypeValueListKey];
          for(var item in subTypeList){
            if(item != allString){
              String searchKey = UtilityMethods.getSearchKey(item);
              String searchItemNameFilterKey = UtilityMethods.getSearchItemNameFilterKey(item);
              String searchItemSlugFilterKey = UtilityMethods.getSearchItemSlugFilterKey(item);
              List value = UtilityMethods.getSubTypeItemRelatedList(item, subTypeValueList);
              if(value.isNotEmpty && value[0].isNotEmpty) {
                dataMap[searchKey] = value[0];
                setRouteRelatedDataMap[searchItemSlugFilterKey] = value[0];
                setRouteRelatedDataMap[searchItemNameFilterKey] = value[1];
              }
            }
          }
        }
        else{
          String key = UtilityMethods.getSearchKey(homeConfigMap[subTypeKey]);
          String searchItemNameFilterKey = UtilityMethods.getSearchItemNameFilterKey(homeConfigMap[subTypeKey]);
          String searchItemSlugFilterKey = UtilityMethods.getSearchItemSlugFilterKey(homeConfigMap[subTypeKey]);
          String value = homeConfigMap[subTypeValueKey] ?? "";
          if(value.isNotEmpty && value != allString && value != userSelectedString){
            dataMap = {key: [value]};
            String itemName = UtilityMethods.getPropertyMetaDataItemNameWithSlug(dataType: homeConfigMap[subTypeKey], slug: value);
            setRouteRelatedDataMap[searchItemSlugFilterKey] = [value];
            setRouteRelatedDataMap[searchItemNameFilterKey] = [itemName];
          }
        }

        if(homeConfigMap[showFeaturedKey] ?? false){
          dataMap[SEARCH_RESULTS_FEATURED] = 1;
          setRouteRelatedDataMap[showFeaturedKey] = true;
        }

        if (homeConfigMap[showNearbyKey] ?? false) {
          if (permissionGranted) {
            Map<String, dynamic> dataMapForNearby = {};
            dataMapForNearby = await UtilityMethods.getMapForNearByProperties();
            dataMap.addAll(dataMapForNearby);
            setRouteRelatedDataMap.addAll(dataMapForNearby);
          } else {
            return [];
          }
        }
        //
        // print("dataMap: $dataMap");
        // print("setRouteRelatedDataMap: $setRouteRelatedDataMap");

        ApiResponse<List> response = await _apiManager.fetchFilteredArticles(params: dataMap);
        if (response.success && response.internet) {
          List<dynamic> filteredArticlesList = response.result;

          if (response.success && response.internet) {
            tempList.addAll(filteredArticlesList);
          }
        }
      }


      /// Fetch realtors list
      else if (homeConfigMap[sectionTypeKey] == agenciesKey ||
          homeConfigMap[sectionTypeKey] == agentsKey) {
        if (homeConfigMap[subTypeKey] == REST_API_AGENT_ROUTE) {
          ApiResponse<List> response = await _apiManager.fetchAllAgents(page, 16, true);
          if (response.success && response.internet) {
            tempList = response.result;
          }
        } else {
          ApiResponse<List> response = await _apiManager.fetchAllAgencies(page, 16,true);
          if (response.success && response.internet) {
            tempList = response.result;
          }
        }
      }


      /// Fetch Terms
      else if (homeConfigMap[sectionTypeKey] == termKey) {
        if(homeConfigMap.containsKey(subTypeListKey) &&
            (homeConfigMap[subTypeListKey] != null &&
                homeConfigMap[subTypeListKey].isNotEmpty)){
          List subTypeList = homeConfigMap[subTypeListKey];
          if(subTypeList.length == 1 && subTypeList[0] == allString){
            Map<String, dynamic> tempMap = {};
            tempMap = removeRedundantLocationTermsKeys(allTermsList);
            setRouteRelatedDataMap.addAll(tempMap);
            ApiResponse<List> response = await _apiManager.fetchTermData(allTermsList);
            if (response.success && response.internet) {
              tempList = response.result;
            }
          }else{
            if(subTypeList.contains(allString)){
              subTypeList.remove(allString);
            }
            Map<String, dynamic> tempMap = {};
            tempMap = removeRedundantLocationTermsKeys(subTypeList);
            setRouteRelatedDataMap.addAll(tempMap);
            ApiResponse<List> response = await _apiManager.fetchTermData(subTypeList);
            if (response.success && response.internet) {
              tempList = response.result;
            }
          }
        }else{
          if(homeConfigMap[subTypeKey] != null && homeConfigMap[subTypeKey].isNotEmpty){
            if(homeConfigMap[subTypeKey] == allString){
              Map<String, dynamic> tempMap = {};
              tempMap = removeRedundantLocationTermsKeys(allTermsList);
              setRouteRelatedDataMap.addAll(tempMap);
              ApiResponse<List> response = await _apiManager.fetchTermData(allTermsList);
              if (response.success && response.internet) {
                tempList = response.result;
              }
            }else{
              var item = homeConfigMap[subTypeKey];
              String key = UtilityMethods.getSearchItemNameFilterKey(item);
              setRouteRelatedDataMap[key] = [allCapString];
              ApiResponse<List> response = await _apiManager.fetchTermData(homeConfigMap[subTypeKey]);
              if (response.success && response.internet) {
                tempList = response.result;
              }
            }
          }
        }
      }

      /// Fetch taxonomies
      else if (homeConfigMap[sectionTypeKey] == termWithIconsTermKey) {
        tempList = [1];
      }

      /// Fetch partners list
      else if (homeConfigMap[sectionTypeKey] == partnersKey) {
        ApiResponse<List> response = await _apiManager.allPartners();
        if (response.success && response.internet) {
          tempList = response.result;
        }
      }

      /// Fetch Blogs list
      else if (homeConfigMap[sectionTypeKey] == blogsKey) {
        ApiResponse<BlogArticlesData?> response = await _apiManager.fetchBlogs("1", "20");
        if (response.success && response.internet && response.result != null) {
          BlogArticlesData blogsData = response.result!;
          tempList = blogsData.articlesList ?? [];
        }
      }

      else {
        tempList = [];
      }
    } on SocketException {
      throw 'No Internet connection';
    }
    return tempList;
  }

  Map<String, dynamic> removeRedundantLocationTermsKeys(List subTypeList){
    Map<String, dynamic> tempMap = {};
    for(var item in subTypeList){
      String key = UtilityMethods.getSearchItemNameFilterKey(item);
      tempMap[key] = [allCapString];
    }
    List<String> keysList = tempMap.keys.toList();
    if(keysList.isNotEmpty) {
      List<String> intersectionKeysList = locationRelatedList.toSet().intersection((keysList.toSet())).toList();
      if (intersectionKeysList.isNotEmpty && intersectionKeysList.length > 1) {
        for (int i = 1; i < intersectionKeysList.length; i++) {
          String key = intersectionKeysList[i];
          tempMap.remove(key);
        }
      }
    }

    return tempMap;
  }

  bool needToLoadData(Map oldDataMap, Map newDataMap){
    if(oldDataMap[sectionTypeKey] != newDataMap[sectionTypeKey] ||
        oldDataMap[subTypeKey] != newDataMap[subTypeKey] ||
        oldDataMap[subTypeValueKey] != newDataMap[subTypeValueKey]){
      return true;
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    if (widget.homeScreenData != homeConfigMap) {
      // Make sure new Home item is Map
      var newHomeConfigMap = widget.homeScreenData;
      if (newHomeConfigMap is! Map) {
        newHomeConfigMap = _apiManager.convertHomeLayoutToJson(widget.homeScreenData);
      }

      if (!(mapEquals(newHomeConfigMap, homeConfigMap))) {
        if (homeConfigMap[sectionTypeKey] != newHomeConfigMap[sectionTypeKey] &&
            newHomeConfigMap[sectionTypeKey] == recentSearchKey) {
          homeScreenList.clear();
          List tempList = HiveStorageManager.readRecentSearchesInfo() ?? [];
          homeScreenList.addAll(tempList);
        } else if (newHomeConfigMap[sectionTypeKey] == adKey) {
          if (SHOW_ADS_ON_HOME) {
            if(!_isNativeAdLoaded){
              setUpNativeAd();
            }

          }
        } else if (newHomeConfigMap[sectionTypeKey] == PLACE_HOLDER_SECTION_TYPE){
          _placeHolderWidget = HooksConfigurations.homeWidgetsHook(
            context,
            newHomeConfigMap[titleKey],
            widget.refresh);
        } else if (needToLoadData(homeConfigMap, newHomeConfigMap)){
          // Update Home Item
          homeConfigMap = newHomeConfigMap;
          loadData();
        }

        // Update Home Item
        homeConfigMap = newHomeConfigMap;
      }
    }

    if(widget.refresh && homeConfigMap[sectionTypeKey] != adKey
        && homeConfigMap[sectionTypeKey] != recentSearchKey
        && homeConfigMap[sectionTypeKey] != PLACE_HOLDER_SECTION_TYPE
    ){
      if(isPageFreeForLoading && mapEquals(widget.selectedItem, widget.homeScreenData)) {
        homeScreenList = [];
        isDataLoaded = false;
        noDataReceived = false;
        isPageFreeForLoading = false;
        // loadData();
        // widget.refresh = false;
      }
    }

    if (homeConfigMap[sectionTypeKey] == PLACE_HOLDER_SECTION_TYPE) {
      if (_placeHolderWidget != null) {
        noDataReceived = false;
        if (widget.refresh) {
          _placeHolderWidget = HooksConfigurations.homeWidgetsHook(
              context,
              homeConfigMap[titleKey],
              widget.refresh);
        }
      } else {
        noDataReceived = true;
      }
    }


    if (homeConfigMap[sectionTypeKey] == termWithIconsTermKey &&
        homeConfigMap[termsWithIconConfiguration] != null &&
        homeConfigMap[termsWithIconConfiguration] is List &&
        homeConfigMap[termsWithIconConfiguration].isNotEmpty) {
      List configList = homeConfigMap[termsWithIconConfiguration];
      _termsWithIconList = configList.map<TermsWithIcon>((item) =>
          _apiManager.parseTermsWithIconJson(item)).toList();
    } else {
      _termsWithIconList = [];
    }
    // print("homeScreenItem: ${homeConfigMap}");

    if (homeConfigMap[sectionTypeKey] == blogsKey &&
        homeConfigMap[designKey] is String &&
        homeConfigMap[designKey].isNotEmpty) {
      BLOGS_DESIGN = UtilityMethods.getDesignValue(homeConfigMap[designKey]) ?? DESIGN_01;
    }

    return Consumer<LocaleProvider>(
        builder: (context, localeProvider, child) {
          if ((homeConfigMap[sectionTypeKey] == allPropertyKey ||
              homeConfigMap[sectionTypeKey] == propertyKey) &&
              homeConfigMap[subTypeKey] == propertyCityDataType) {
            Map<String, dynamic> map = HiveStorageManager.readSelectedCityInfo();
            String cityId = UtilityMethods.valueForKeyOrEmpty(map, CITY_ID);
            String city = UtilityMethods.valueForKeyOrEmpty(map, CITY);
            homeConfigMap[titleKey] = UtilityMethods.titleForSectionBasedOnCitySelection(homeConfigMap, city);
            if (cityId.isNotEmpty) {
              homeConfigMap[subTypeValueCityKey] = cityId;
            }
          }

          if(homeConfigMap[sectionTypeKey] == recentSearchKey && homeScreenList.isNotEmpty){
            homeScreenList.removeWhere((element) => element is! Map);
          }

          return noDataReceived
              ? Container()
              : Column(
              children: [
                if (homeConfigMap[sectionTypeKey] == recentSearchKey)
                  homeScreenList.isEmpty
                      ? NoResultErrorWidget(
                          headerErrorText: UtilityMethods.getLocalizedString(
                              "no_result_found"),
                          bodyErrorText: UtilityMethods.getLocalizedString(
                              "no_recent_properties_error_message"),
                          hideGoBackButton: true,
                        )
                      : HomeScreenRecentSearchesWidget(
                          recentSearchesInfoList:
                              HiveStorageManager.readRecentSearchesInfo() ?? [],
                          // listingView: homeScreenWidgetsListingCarouselView,
                          // listingView: homeScreenWidgetsListingListView,
                          listingView: homeConfigMap[sectionListingViewKey] ??
                              homeScreenWidgetsListingListView,
                        ),
                if (homeConfigMap[sectionTypeKey] == adKey &&
                    SHOW_ADS_ON_HOME &&
                    _isNativeAdLoaded)
                  Container(
                    padding: const EdgeInsets.only(left: 10, right: 10),
                    height: 50,
                    child: AdWidget(ad: _nativeAd!),
                  ),
                if (homeConfigMap[sectionTypeKey] == termWithIconsTermKey)
                  Container(
                    padding: const EdgeInsets.only(top: 5.0),
                    child: _termsWithIconList.isNotEmpty
                        ? DynamicTermsWithIconWidget(dataList: _termsWithIconList)
                        : TermWithIconsWidget(),
                  ),
                if (homeConfigMap[sectionTypeKey] == allPropertyKey ||
                    homeConfigMap[sectionTypeKey] == propertyKey ||
                    homeConfigMap[sectionTypeKey] == featuredPropertyKey)
                  if (isDataLoaded)
                    genericWidgetWithSeeAllOption(
                      onTap: () => setRouteToNavigate(),
                      widget: PropertiesListingGenericWidget(
                        propertiesList: homeScreenList,
                        design: UtilityMethods.getHomePropertyItemDesignName(homeConfigMap),
                        // listingView: homeScreenWidgetsListingCarouselView,
                        // listingView: homeScreenWidgetsListingListView,
                        listingView: homeConfigMap[sectionListingViewKey] ??
                            homeScreenWidgetsListingListView,
                      ),
                    )
                  else
                    genericLoadingWidgetForCarousalWithShimmerEffect(context),
                if (homeConfigMap[sectionTypeKey] == termKey)
                  if (isDataLoaded)
                    ExplorePropertiesWidget(
                      design: UtilityMethods.getDesignValue(
                          homeConfigMap[designKey]),
                      propertiesData: homeScreenList,
                      // listingView: homeScreenWidgetsListingCarouselView,
                      // listingView: homeScreenWidgetsListingListView,
                      listingView: homeConfigMap[sectionListingViewKey] ??
                          homeScreenWidgetsListingListView,
                      explorePropertiesWidgetListener: ({filterDataMap}) {
                        if (filterDataMap != null &&
                            filterDataMap.isNotEmpty) {}
                      },
                    )
                  else
                    genericLoadingWidgetForCarousalWithShimmerEffect(context),
                if (homeConfigMap[sectionTypeKey] == agenciesKey ||
                    homeConfigMap[sectionTypeKey] == agentsKey)
                  if (isDataLoaded &&
                      homeScreenList.isNotEmpty &&
                      homeScreenList is List)
                    genericWidgetWithSeeAllOption(
                        onTap: () => setRouteToNavigate(),
                        widget: RealtorListingsWidget(
                          tag: homeConfigMap[subTypeKey] == REST_API_AGENT_ROUTE
                              ? AGENTS_TAG
                              : AGENCIES_TAG,
                          realtorInfoList: homeScreenList,
                          // listingView: homeScreenWidgetsListingCarouselView,
                          // listingView: homeScreenWidgetsListingListView,
                          listingView: homeConfigMap[sectionListingViewKey] ??
                              homeScreenWidgetsListingListView,
                        ))
                  else
                    genericLoadingWidgetForCarousalWithShimmerEffect(context),

                if (homeConfigMap[sectionTypeKey] == PLACE_HOLDER_SECTION_TYPE &&
                    _placeHolderWidget != null) _placeHolderWidget!,

                if (homeConfigMap[sectionTypeKey] == partnersKey)
                  PartnerWidget(
                    partnersList: homeScreenList,
                    // listingView: LIST_VIEW,
                    // listingView: CAROUSEL_VIEW,
                    listingView: homeConfigMap[sectionListingViewKey] ?? CAROUSEL_VIEW,
                  ),

                if (homeConfigMap[sectionTypeKey] == blogsKey)
                  genericWidgetWithSeeAllOption(
                    onTap: () => setRouteToNavigate(),
                    widget: BlogsListingWidget(
                      view: homeConfigMap[sectionListingViewKey] ?? CAROUSEL_VIEW,
                      design: UtilityMethods.getDesignValue(homeConfigMap[designKey]) ?? DESIGN_01,
                      articlesList: List<BlogArticle>.from(homeScreenList),
                    ),
                  ),
              ],
            );
    });
  }

  Widget genericWidgetWithSeeAllOption({
    required Widget widget,
    required Function() onTap,
}){
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        widget,
        GestureDetector(
          onTap: onTap,
          child: Padding(
            padding: EdgeInsets.only(
                left : UtilityMethods.isRTL(context) ? 20 : 0,
                right: UtilityMethods.isRTL(context) ? 0 : 20,
                top: 5,
                bottom: 20
            ),
            child: GenericTextWidget(
              UtilityMethods.getLocalizedString("see_all") + arrowDirection,
              style: AppThemePreferences().appTheme.readMoreTextStyle,
            ),
          ),
        ),
      ],
    );
  }


  setRouteToNavigate() async {
    StatefulWidget Function(dynamic context)? route;
    if (homeConfigMap[sectionTypeKey] == featuredPropertyKey) {
      route = getSearchResultPath(onlyFeatured: true);
    }
    else if (homeConfigMap[sectionTypeKey] == allPropertyKey &&
        homeConfigMap[subTypeKey] != propertyCityDataType) {
      Map<String, dynamic> dataMap = {
        UtilityMethods.getSearchKey(homeConfigMap[subTypeKey]): "",
      };
      route = getSearchResultPath(map: dataMap);
    } else if (homeConfigMap[sectionTypeKey] == termKey) {
      route = getSearchResultPath(map: setRouteRelatedDataMap);
    } else if (homeConfigMap[subTypeKey] == agenciesKey) {
      route = (context) => AllAgency();
    } else if (homeConfigMap[subTypeKey] == agentsKey) {
      route = (context) => AllAgents();
    } else if (homeConfigMap[sectionTypeKey] == allPropertyKey) {
      Map<String, dynamic> dataMap = {};
      dataMap.addAll(setRouteRelatedDataMap);
      // if (UtilityMethods.listDependsOnUserSelection(homeConfigMap)) {
      //   Map<String, dynamic> cityInfoMap = HiveStorageManager.readSelectedCityInfo();
      //   String citySlug = UtilityMethods.valueForKeyOrEmpty(
      //       cityInfoMap, CITY_SLUG);
      //   String city = UtilityMethods.valueForKeyOrEmpty(cityInfoMap, CITY);
      //   if (city.isNotEmpty) {
      //     dataMap[CITY_SLUG] = citySlug;
      //     dataMap[CITY] = city;
      //   } else {
      //     dataMap[CITY] = allCapString;
      //   }
      // }
      route = getSearchResultPath(map: dataMap);
    } else if (homeConfigMap[sectionTypeKey] == blogsKey) {
      route = (context) => AllBlogsPage(
        title: homeConfigMap[titleKey],
        blogDesign: UtilityMethods.getDesignValue(homeConfigMap[designKey]) ?? DESIGN_01,
      );
    } else if (homeConfigMap[sectionTypeKey] == propertyKey) {
      Map<String, dynamic> dataMap = {};
      dataMap.addAll(setRouteRelatedDataMap);
      if(UtilityMethods.listDependsOnUserSelection(homeConfigMap)) {
        Map<String, dynamic> cityInfoMap = HiveStorageManager.readSelectedCityInfo();
        String citySlug = UtilityMethods.valueForKeyOrEmpty(cityInfoMap, CITY_SLUG);
        String city = UtilityMethods.valueForKeyOrEmpty(cityInfoMap, CITY);
        if (city.isNotEmpty) {
          dataMap[CITY_SLUG] = citySlug;
          dataMap[CITY] = city;
        }else{
          dataMap[CITY] = allCapString;
        }
      }
      bool featured = dataMap[showFeaturedKey] != null && dataMap[showFeaturedKey] is bool && dataMap[showFeaturedKey] ? true : false;
      route = getSearchResultPath(
        onlyFeatured: featured,
        map: dataMap,
      );
    } else {
      route = null;
    }
    navigateToRoute(route);
  }

  getSearchResultPath({Map<String, dynamic>? map, bool onlyFeatured = false}){
    return (context) => SearchResult(
      dataInitializationMap:  map,
      searchPageListener: (Map<String, dynamic> map, String closeOption) {
        if(closeOption.isEmpty){
          GeneralNotifier().publishChange(GeneralNotifier.FILTER_DATA_LOADING_COMPLETE);
        }
        if (closeOption == CLOSE) {
          Navigator.of(context).pop();
        }
      },
    );
  }

  navigateToRoute(WidgetBuilder? builder) {
    if (builder != null) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: builder,
        ),
      );
    }
  }

  @override
  // TODO: implement wantKeepAlive
  bool get wantKeepAlive => true;
}