/*
 @licstart  The following is the entire license notice for the JavaScript code in this file.

 The MIT License (MIT)

 Copyright (C) 1997-2020 by Dimitri van Heesch

 Permission is hereby granted, free of charge, to any person obtaining a copy of this software
 and associated documentation files (the "Software"), to deal in the Software without restriction,
 including without limitation the rights to use, copy, modify, merge, publish, distribute,
 sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is
 furnished to do so, subject to the following conditions:

 The above copyright notice and this permission notice shall be included in all copies or
 substantial portions of the Software.

 THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING
 BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
 NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM,
 DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

 @licend  The above is the entire license notice for the JavaScript code in this file
 */
const SEARCH_COOKIE_NAME = ''+'search_grp';

const searchResults = new SearchResults();

/* A class handling everything associated with the search panel.

   Parameters:
   name - The name of the global variable that will be
          storing this instance.  Is needed to be able to set timeouts.
   resultPath - path to use for external files
*/
/**
 * @description Manages the search panel's state, including hiding or showing the
 * results window, resetting search field value, and activating or deactivating the
 * search box based on its display style.
 * 
 * @param { object } name - name of the form element that triggered the `searchFunction`
 * function, and it is used to identify the source of the search query and process
 * its results accordingly.
 * 
 * @param { string } resultsPath - path where the search results are stored, and it
 * is used to load the search results from the corresponding file when a search query
 * is entered, by calling the `createResults` function with the correct path.
 * 
 * @param { string } extension - extension of the search query, and it is used to
 * filter the search results by changing the query based on the inputted extension.
 * 
 * @returns { undefined` because no return statement has been defined } a JavaScript
 * function that performs a search and displays the results in a popup window.
 * 
 * 		- `searchIndex`: The index of the currently selected search result.
 * 		- `resultsPath`: A path to the directory containing the search results files.
 * 		- `searchValue`: The value of the search field, used for searching the database.
 * 		- `searchResults`: An instance of the `SearchResults` class, which represents
 * the search results.
 * 		- `lastSearchValue`: The last value entered in the search field.
 * 		- `lastResultsPage`: The page number of the last searched results page.
 * 		- `DOMSearchBox`: A reference to the search box HTML element.
 * 		- `DOMPopupSearchResultsWindow`: A reference to the popup window containing the
 * search results.
 * 		- `DOMSearchClose`: A reference to the close button inside the popup window.
 * 		- `DOMSearchField`: A reference to the search field HTML element.
 * 
 * 	The following attributes are also defined:
 * 
 * 		- `keyTimeout`: A variable used to handle keyboard events.
 * 		- `isActive`: A flag indicating whether the search panel is active or not.
 * 		- `searchActive`: A flag indicating whether the search box is in use or not.
 */
function SearchBox(name, resultsPath, extension) {
  if (!name || !resultsPath) {  alert("Missing parameters to SearchBox."); }
  if (!extension || extension == "") { extension = ".html"; }

  /**
   * @description Calculates the x-coordinate of an element based on its offsetWidth
   * property and parent-child relationships.
   * 
   * @param { `HTMLElement`. } item - element for which the left offset position is to
   * be calculated.
   * 
   * 		- `offsetWidth`: A boolean property that indicates whether the `item` has an
   * explicit width defined or not.
   * 		- `offsetLeft`: A number property representing the left position of the `item`
   * relative to its parent element in the Document Object Model (DOM).
   * 		- `offsetParent`: A reference to the parent element of the `item` in the DOM.
   * 
   * @returns { integer } the total offset left of the element from the starting point.
   */
  function getXPos(item) {
    let x = 0;
    if (item.offsetWidth) {
      while (item && item!=document.body) {
        x   += item.offsetLeft;
        item = item.offsetParent;
      }
    }
    return x;
  }

  /**
   * @description Calculates the position of an element relative to the document's body
   * by traversing the element's parents and adding up their offset top values.
   * 
   * @param { object } item - element whose `offsetTop` value is calculated to determine
   * its position on the page.
   * 
   * @returns { integer } the sum of the top positions of all parent elements until the
   * document body is reached.
   */
  function getYPos(item) {
    let y = 0;
    if (item.offsetWidth) {
      while (item && item!=document.body) {
        y   += item.offsetTop;
        item = item.offsetParent;
      }
    }
    return y;
  }

  // ---------- Instance variables
  this.name                  = name;
  this.resultsPath           = resultsPath;
  this.keyTimeout            = 0;
  this.keyTimeoutLength      = 500;
  this.closeSelectionTimeout = 300;
  this.lastSearchValue       = "";
  this.lastResultsPage       = "";
  this.hideTimeout           = 0;
  this.searchIndex           = 0;
  this.searchActive          = false;
  this.extension             = extension;

  // ----------- DOM Elements

  this.DOMSearchField              = () => document.getElementById("MSearchField");
  this.DOMSearchSelect             = () => document.getElementById("MSearchSelect");
  this.DOMSearchSelectWindow       = () => document.getElementById("MSearchSelectWindow");
  this.DOMPopupSearchResults       = () => document.getElementById("MSearchResults");
  this.DOMPopupSearchResultsWindow = () => document.getElementById("MSearchResultsWindow");
  this.DOMSearchClose              = () => document.getElementById("MSearchClose");
  this.DOMSearchBox                = () => document.getElementById("MSearchBox");

  // ------------ Event Handlers

  // Called when focus is added or removed from the search field.
  this.OnSearchFieldFocus = function(isActive) {
    this.Activate(isActive);
  }

  this.OnSearchSelectShow = function() {
    const searchSelectWindow = this.DOMSearchSelectWindow();
    const searchField        = this.DOMSearchSelect();

    const left = getXPos(searchField);
    const top  = getYPos(searchField) + searchField.offsetHeight;

    // show search selection popup
    searchSelectWindow.style.display='block';
    searchSelectWindow.style.left =  left + 'px';
    searchSelectWindow.style.top  =  top  + 'px';

    // stop selection hide timer
    if (this.hideTimeout) {
      clearTimeout(this.hideTimeout);
      this.hideTimeout=0;
    }
    return false; // to avoid "image drag" default event
  }

  this.OnSearchSelectHide = function() {
    this.hideTimeout = setTimeout(this.CloseSelectionWindow.bind(this),
                                  this.closeSelectionTimeout);
  }

  // Called when the content of the search field is changed.
  this.OnSearchFieldChange = function(evt) {
    if (this.keyTimeout) { // kill running timer
      clearTimeout(this.keyTimeout);
      this.keyTimeout = 0;
    }

    const e = evt ? evt : window.event; // for IE
    if (e.keyCode==40 || e.keyCode==13) {
      if (e.shiftKey==1) {
        this.OnSearchSelectShow();
        const win=this.DOMSearchSelectWindow();
        for (let i=0;i<win.childNodes.length;i++) {
          const child = win.childNodes[i]; // get span within a
          if (child.className=='SelectItem') {
            child.focus();
            return;
          }
        }
        return;
      } else {
        const elem = searchResults.NavNext(0);
        if (elem) elem.focus();
      }
    } else if (e.keyCode==27) { // Escape out of the search field
      e.stopPropagation();
      this.DOMSearchField().blur();
      this.DOMPopupSearchResultsWindow().style.display = 'none';
      this.DOMSearchClose().style.display = 'none';
      this.lastSearchValue = '';
      this.Activate(false);
      return;
    }

    // strip whitespaces
    const searchValue = this.DOMSearchField().value.replace(/ +/g, "");

    if (searchValue != this.lastSearchValue) { // search value has changed
      if (searchValue != "") { // non-empty search
        // set timer for search update
        this.keyTimeout = setTimeout(this.Search.bind(this), this.keyTimeoutLength);
      } else { // empty search field
        this.DOMPopupSearchResultsWindow().style.display = 'none';
        this.DOMSearchClose().style.display = 'none';
        this.lastSearchValue = '';
      }
    }
  }

  this.SelectItemCount = function() {
    let count=0;
    const win=this.DOMSearchSelectWindow();
    for (let i=0;i<win.childNodes.length;i++) {
      const child = win.childNodes[i]; // get span within a
      if (child.className=='SelectItem') {
        count++;
      }
    }
    return count;
  }

  this.GetSelectionIdByName = function(name) {
    let j=0;
    const win=this.DOMSearchSelectWindow();
    for (let i=0;i<win.childNodes.length;i++) {
      const child = win.childNodes[i];
      if (child.className=='SelectItem') {
        if (child.childNodes[1].nodeValue==name) {
          return j;
        }
        j++;
      }
    }
    return 0;
  }

  this.SelectItemSet = function(id) {
    let j=0;
    const win=this.DOMSearchSelectWindow();
    for (let i=0;i<win.childNodes.length;i++) {
      const child = win.childNodes[i]; // get span within a
      if (child.className=='SelectItem') {
        const node = child.firstChild;
        if (j==id) {
          node.innerHTML='&#8226;';
          Cookie.writeSetting(SEARCH_COOKIE_NAME, child.childNodes[1].nodeValue, 0)
        } else {
          node.innerHTML='&#160;';
        }
        j++;
      }
    }
  }

  // Called when an search filter selection is made.
  // set item with index id as the active item
  this.OnSelectItem = function(id) {
    this.searchIndex = id;
    this.SelectItemSet(id);
    const searchValue = this.DOMSearchField().value.replace(/ +/g, "");
    if (searchValue!="" && this.searchActive) { // something was found -> do a search
      this.Search();
    }
  }

  this.OnSearchSelectKey = function(evt) {
    const e = (evt) ? evt : window.event; // for IE
    if (e.keyCode==40 && this.searchIndex<this.SelectItemCount()) { // Down
      this.searchIndex++;
      this.OnSelectItem(this.searchIndex);
    } else if (e.keyCode==38 && this.searchIndex>0) { // Up
      this.searchIndex--;
      this.OnSelectItem(this.searchIndex);
    } else if (e.keyCode==13 || e.keyCode==27) {
      e.stopPropagation();
      this.OnSelectItem(this.searchIndex);
      this.CloseSelectionWindow();
      this.DOMSearchField().focus();
    }
    return false;
  }

  // --------- Actions

  // Closes the results window.
  this.CloseResultsWindow = function() {
    this.DOMPopupSearchResultsWindow().style.display = 'none';
    this.DOMSearchClose().style.display = 'none';
    this.Activate(false);
  }

  this.CloseSelectionWindow = function() {
    this.DOMSearchSelectWindow().style.display = 'none';
  }

  // Performs a search.
  this.Search = function() {
    this.keyTimeout = 0;

    // strip leading whitespace
    const searchValue = this.DOMSearchField().value.replace(/^ +/, "");

    const code = searchValue.toLowerCase().charCodeAt(0);
    let idxChar = searchValue.substr(0, 1).toLowerCase();
    if ( 0xD800 <= code && code <= 0xDBFF && searchValue > 1) { // surrogate pair
      idxChar = searchValue.substr(0, 2);
    }

    let jsFile;
    let idx = indexSectionsWithContent[this.searchIndex].indexOf(idxChar);
    if (idx!=-1) {
      const hexCode=idx.toString(16);
      jsFile = this.resultsPath + indexSectionNames[this.searchIndex] + '_' + hexCode + '.js';
    }

    const loadJS = function(url, impl, loc) {
      const scriptTag = document.createElement('script');
      scriptTag.src = url;
      scriptTag.onload = impl;
      scriptTag.onreadystatechange = impl;
      loc.appendChild(scriptTag);
    }

    const domPopupSearchResultsWindow = this.DOMPopupSearchResultsWindow();
    const domSearchBox = this.DOMSearchBox();
    const domPopupSearchResults = this.DOMPopupSearchResults();
    const domSearchClose = this.DOMSearchClose();
    const resultsPath = this.resultsPath;

    const handleResults = function() {
      document.getElementById("Loading").style.display="none";
      if (typeof searchData !== 'undefined') {
        createResults(resultsPath);
        document.getElementById("NoMatches").style.display="none";
      }

      if (idx!=-1) {
        searchResults.Search(searchValue);
      } else { // no file with search results => force empty search results
        searchResults.Search('====');
      }

      if (domPopupSearchResultsWindow.style.display!='block') {
        domSearchClose.style.display = 'inline-block';
        let left = getXPos(domSearchBox) + 150;
        let top  = getYPos(domSearchBox) + 20;
        domPopupSearchResultsWindow.style.display = 'block';
        left -= domPopupSearchResults.offsetWidth;
        const maxWidth  = document.body.clientWidth;
        const maxHeight = document.body.clientHeight;
        let width = 300;
        if (left<10) left=10;
        if (width+left+8>maxWidth) width=maxWidth-left-8;
        let height = 400;
        if (height+top+8>maxHeight) height=maxHeight-top-8;
        domPopupSearchResultsWindow.style.top     = top  + 'px';
        domPopupSearchResultsWindow.style.left    = left + 'px';
        domPopupSearchResultsWindow.style.width   = width + 'px';
        domPopupSearchResultsWindow.style.height  = height + 'px';
      }
    }

    if (jsFile) {
      loadJS(jsFile, handleResults, this.DOMPopupSearchResultsWindow());
    } else {
      handleResults();
    }

    this.lastSearchValue = searchValue;
  }

  // -------- Activation Functions

  // Activates or deactivates the search panel, resetting things to
  // their default values if necessary.
  this.Activate = function(isActive) {
    if (isActive || // open it
      this.DOMPopupSearchResultsWindow().style.display == 'block'
    ) {
      this.DOMSearchBox().className = 'MSearchBoxActive';
      this.searchActive = true;
    } else if (!isActive) { // directly remove the panel
      this.DOMSearchBox().className = 'MSearchBoxInactive';
      this.searchActive             = false;
      this.lastSearchValue          = ''
      this.lastResultsPage          = '';
      this.DOMSearchField().value   = '';
    }
  }
}

// -----------------------------------------------------------------------

// The class that handles everything on the search results page.
/**
 * @description Manages a search results window's navigation through children elements
 * based on arrow key presses. It handles keyboard input and calls child element's
 * `Focus` method to focus on the appropriate element.
 * 
 * @returns { boolean } a boolean indicating whether the Enter key was pressed.
 */
function SearchResults() {

  /**
   * @description Takes a string `search` and converts each character to an identifier
   * using a specific algorithm. The resulting string is returned as the converted identifier.
   * 
   * @param { string } search - search term that the function will convert into an identifier.
   * 
   * @returns { string } a unique identifier formed by concatenating uppercase letters,
   * digits, and underscores based on the input search string.
   */
  function convertToId(search) {
    let result = '';
    for (let i=0;i<search.length;i++) {
      const c = search.charAt(i);
      const cn = c.charCodeAt(0);
      if (c.match(/[a-z0-9\u0080-\uFFFF]/)) {
        result+=c;
      } else if (cn<16) {
        result+="_0"+cn.toString(16);
      } else {
        result+="_"+cn.toString(16);
      }
    }
    return result;
  }

  // The number of matches from the last run of <Search()>.
  this.lastMatchCount = 0;
  this.lastKey = 0;
  this.repeatOn = false;

  // Toggles the visibility of the passed element ID.
  this.FindChildElement = function(id) {
    const parentElement = document.getElementById(id);
    let element = parentElement.firstChild;

    while (element && element!=parentElement) {
      if (element.nodeName.toLowerCase() == 'div' && element.className == 'SRChildren') {
        return element;
      }

      if (element.nodeName.toLowerCase() == 'div' && element.hasChildNodes()) {
        element = element.firstChild;
      } else if (element.nextSibling) {
        element = element.nextSibling;
      } else {
        do {
          element = element.parentNode;
        }
        while (element && element!=parentElement && !element.nextSibling);

        if (element && element!=parentElement) {
          element = element.nextSibling;
        }
      }
    }
  }

  this.Toggle = function(id) {
    const element = this.FindChildElement(id);
    if (element) {
      if (element.style.display == 'block') {
        element.style.display = 'none';
      } else {
        element.style.display = 'block';
      }
    }
  }

  // Searches for the passed string.  If there is no parameter,
  // it takes it from the URL query.
  //
  // Always returns true, since other documents may try to call it
  // and that may or may not be possible.
  this.Search = function(search) {
    if (!search) { // get search word from URL
      search = window.location.search;
      search = search.substring(1);  // Remove the leading '?'
      search = unescape(search);
    }

    search = search.replace(/^ +/, ""); // strip leading spaces
    search = search.replace(/ +$/, ""); // strip trailing spaces
    search = search.toLowerCase();
    search = convertToId(search);

    const resultRows = document.getElementsByTagName("div");
    let matches = 0;

    let i = 0;
    while (i < resultRows.length) {
      const row = resultRows.item(i);
      if (row.className == "SRResult") {
        let rowMatchName = row.id.toLowerCase();
        rowMatchName = rowMatchName.replace(/^sr\d*_/, ''); // strip 'sr123_'

        if (search.length<=rowMatchName.length &&
          rowMatchName.substr(0, search.length)==search) {
          row.style.display = 'block';
          matches++;
        } else {
          row.style.display = 'none';
        }
      }
      i++;
    }
    document.getElementById("Searching").style.display='none';
    if (matches == 0) { // no results
      document.getElementById("NoMatches").style.display='block';
    } else { // at least one result
      document.getElementById("NoMatches").style.display='none';
    }
    this.lastMatchCount = matches;
    return true;
  }

  // return the first item with index index or higher that is visible
  this.NavNext = function(index) {
    let focusItem;
    for (;;) {
      const focusName = 'Item'+index;
      focusItem = document.getElementById(focusName);
      if (focusItem && focusItem.parentNode.parentNode.style.display=='block') {
        break;
      } else if (!focusItem) { // last element
        break;
      }
      focusItem=null;
      index++;
    }
    return focusItem;
  }

  this.NavPrev = function(index) {
    let focusItem;
    for (;;) {
      const focusName = 'Item'+index;
      focusItem = document.getElementById(focusName);
      if (focusItem && focusItem.parentNode.parentNode.style.display=='block') {
        break;
      } else if (!focusItem) { // last element
        break;
      }
      focusItem=null;
      index--;
    }
    return focusItem;
  }

  this.ProcessKeys = function(e) {
    if (e.type == "keydown") {
      this.repeatOn = false;
      this.lastKey = e.keyCode;
    } else if (e.type == "keypress") {
      if (!this.repeatOn) {
        if (this.lastKey) this.repeatOn = true;
        return false; // ignore first keypress after keydown
      }
    } else if (e.type == "keyup") {
      this.lastKey = 0;
      this.repeatOn = false;
    }
    return this.lastKey!=0;
  }

  this.Nav = function(evt,itemIndex) {
    const e  = (evt) ? evt : window.event; // for IE
    if (e.keyCode==13) return true;
    if (!this.ProcessKeys(e)) return false;

    if (this.lastKey==38) { // Up
      const newIndex = itemIndex-1;
      let focusItem = this.NavPrev(newIndex);
      if (focusItem) {
        let child = this.FindChildElement(focusItem.parentNode.parentNode.id);
        if (child && child.style.display == 'block') { // children visible
          let n=0;
          let tmpElem;
          for (;;) { // search for last child
            tmpElem = document.getElementById('Item'+newIndex+'_c'+n);
            if (tmpElem) {
              focusItem = tmpElem;
            } else { // found it!
              break;
            }
            n++;
          }
        }
      }
      if (focusItem) {
        focusItem.focus();
      } else { // return focus to search field
        document.getElementById("MSearchField").focus();
      }
    } else if (this.lastKey==40) { // Down
      const newIndex = itemIndex+1;
      let focusItem;
      const item = document.getElementById('Item'+itemIndex);
      const elem = this.FindChildElement(item.parentNode.parentNode.id);
      if (elem && elem.style.display == 'block') { // children visible
        focusItem = document.getElementById('Item'+itemIndex+'_c0');
      }
      if (!focusItem) focusItem = this.NavNext(newIndex);
      if (focusItem)  focusItem.focus();
    } else if (this.lastKey==39) { // Right
      const item = document.getElementById('Item'+itemIndex);
      const elem = this.FindChildElement(item.parentNode.parentNode.id);
      if (elem) elem.style.display = 'block';
    } else if (this.lastKey==37) { // Left
      const item = document.getElementById('Item'+itemIndex);
      const elem = this.FindChildElement(item.parentNode.parentNode.id);
      if (elem) elem.style.display = 'none';
    } else if (this.lastKey==27) { // Escape
      e.stopPropagation();
      searchBox.CloseResultsWindow();
      document.getElementById("MSearchField").focus();
    } else if (this.lastKey==13) { // Enter
      return true;
    }
    return false;
  }

  this.NavChild = function(evt,itemIndex,childIndex) {
    const e  = (evt) ? evt : window.event; // for IE
    if (e.keyCode==13) return true;
    if (!this.ProcessKeys(e)) return false;

    if (this.lastKey==38) { // Up
      if (childIndex>0) {
        const newIndex = childIndex-1;
        document.getElementById('Item'+itemIndex+'_c'+newIndex).focus();
      } else { // already at first child, jump to parent
        document.getElementById('Item'+itemIndex).focus();
      }
    } else if (this.lastKey==40) { // Down
      const newIndex = childIndex+1;
      let elem = document.getElementById('Item'+itemIndex+'_c'+newIndex);
      if (!elem) { // last child, jump to parent next parent
        elem = this.NavNext(itemIndex+1);
      }
      if (elem) {
        elem.focus();
      }
    } else if (this.lastKey==27) { // Escape
      e.stopPropagation();
      searchBox.CloseResultsWindow();
      document.getElementById("MSearchField").focus();
    } else if (this.lastKey==13) { // Enter
      return true;
    }
    return false;
  }
}

/**
 * @description Generates and appends HTML elements containing search results to an
 * existing `div` element with the id `SRResults`.
 * 
 * @param { string } resultsPath - URL path where the search results links should
 * lead to when clicked.
 */
function createResults(resultsPath) {

  /**
   * @description Sets attribute values for an element based on an action string provided.
   * It adds `onkeydown`, `onkeypress`, and `onkeyup` attributes with the given action
   * value.
   * 
   * @param { element. } elem - HTML element for which the key actions are to be set.
   * 
   * 		- `elem`: This is the HTML element to which actions will be set for key events.
   * 		- `action`: This is the action that will be triggered when a key event occurs
   * on the `elem`.
   * 
   * @param { string } action - onkeydown, onkeypress and onkeyup event actions for the
   * specified HTML element, which are added to the element's attribute list through
   * the setKeyActions function call.
   */
  function setKeyActions(elem,action) {
    elem.setAttribute('onkeydown',action);
    elem.setAttribute('onkeypress',action);
    elem.setAttribute('onkeyup',action);
  }

  /**
   * @description Sets the `class` or `className` attribute of an element to a given
   * value, `attr`.
   * 
   * @param { HTML Element. } elem - HTML element to which the class attribute will be
   * set.
   * 
   * 		- `attr`: A string that represents the value to be assigned as the class attribute
   * for the element.
   * 
   * @param { string } attr - new value of the element's `class` attribute, which is
   * then assigned to the element using the `setAttribute()` method.
   */
  function setClassAttr(elem,attr) {
    elem.setAttribute('class',attr);
    elem.setAttribute('className',attr);
  }

  const results = document.getElementById("SRResults");
  results.innerHTML = '';
  searchData.forEach((elem,index) => {
    const id = elem[0];
    const srResult = document.createElement('div');
    srResult.setAttribute('id','SR_'+id);
    setClassAttr(srResult,'SRResult');
    const srEntry = document.createElement('div');
    setClassAttr(srEntry,'SREntry');
    const srLink = document.createElement('a');
    srLink.setAttribute('id','Item'+index);
    setKeyActions(srLink,'return searchResults.Nav(event,'+index+')');
    setClassAttr(srLink,'SRSymbol');
    srLink.innerHTML = elem[1][0];
    srEntry.appendChild(srLink);
    if (elem[1].length==2) { // single result
      srLink.setAttribute('href',resultsPath+elem[1][1][0]);
      srLink.setAttribute('onclick','searchBox.CloseResultsWindow()');
      if (elem[1][1][1]) {
       srLink.setAttribute('target','_parent');
      } else {
       srLink.setAttribute('target','_blank');
      }
      const srScope = document.createElement('span');
      setClassAttr(srScope,'SRScope');
      srScope.innerHTML = elem[1][1][2];
      srEntry.appendChild(srScope);
    } else { // multiple results
      srLink.setAttribute('href','javascript:searchResults.Toggle("SR_'+id+'")');
      const srChildren = document.createElement('div');
      setClassAttr(srChildren,'SRChildren');
      for (let c=0; c<elem[1].length-1; c++) {
        const srChild = document.createElement('a');
        srChild.setAttribute('id','Item'+index+'_c'+c);
        setKeyActions(srChild,'return searchResults.NavChild(event,'+index+','+c+')');
        setClassAttr(srChild,'SRScope');
        srChild.setAttribute('href',resultsPath+elem[1][c+1][0]);
        srChild.setAttribute('onclick','searchBox.CloseResultsWindow()');
        if (elem[1][c+1][1]) {
         srChild.setAttribute('target','_parent');
        } else {
         srChild.setAttribute('target','_blank');
        }
        srChild.innerHTML = elem[1][c+1][2];
        srChildren.appendChild(srChild);
      }
      srEntry.appendChild(srChildren);
    }
    srResult.appendChild(srEntry);
    results.appendChild(srResult);
  });
}

/**
 * @description 1) creates links for search results and sets their `tabIndex`, 2)
 * adds an event listener to a search input field, 3) handles keyboard inputs to
 * toggle the search selection window, 4) retrieves the selected name from cookies
 * and 5) calls the `OnSelectItem` method with the corresponding ID.
 */
function init_search() {
  const results = document.getElementById("MSearchSelectWindow");

  results.tabIndex=0;
  for (let key in indexSectionLabels) {
    const link = document.createElement('a');
    link.setAttribute('class','SelectItem');
    link.setAttribute('onclick','searchBox.OnSelectItem('+key+')');
    link.href='javascript:void(0)';
    link.innerHTML='<span class="SelectionMark">&#160;</span>'+indexSectionLabels[key];
    results.appendChild(link);
  }

  const input = document.getElementById("MSearchSelect");
  const searchSelectWindow = document.getElementById("MSearchSelectWindow");
  input.tabIndex=0;
  input.addEventListener("keydown", function(event) {
    if (event.keyCode==13 || event.keyCode==40) {
      event.preventDefault();
      if (searchSelectWindow.style.display == 'block') {
        searchBox.CloseSelectionWindow();
      } else {
        searchBox.OnSearchSelectShow();
        searchBox.DOMSearchSelectWindow().focus();
      }
    }
  });
  const name = Cookie.readSetting(SEARCH_COOKIE_NAME,0);
  const id = searchBox.GetSelectionIdByName(name);
  searchBox.OnSelectItem(id);
}
/* @license-end */
