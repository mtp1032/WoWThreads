/*!
 Cookie helper functions
 Copyright (c) 2023 Dimitri van Heesch
 Released under MIT license.
*/
let Cookie = {
  cookie_namespace: 'doxygen_',

  /**
   * @description Retrieves a setting value from either local storage or the document
   * cookie, and returns it if found, or a default value otherwise.
   * 
   * @param { string } cookie - name of the cookie to be looked up in local or session
   * storage.
   * 
   * @param { string } defVal - default value returned if the function fails to find
   * the cookie value in the storage.
   * 
   * @returns { string } the value of a cookie setting, or the default value if the
   * cookie is not found.
   */
  readSetting(cookie,defVal) {
    if (window.chrome) {
      const val = localStorage.getItem(this.cookie_namespace+cookie) ||
                  sessionStorage.getItem(this.cookie_namespace+cookie);
      if (val) return val;
    } else {
      let myCookie = this.cookie_namespace+cookie+"=";
      if (document.cookie) {
        const index = document.cookie.indexOf(myCookie);
        if (index != -1) {
          const valStart = index + myCookie.length;
          let valEnd = document.cookie.indexOf(";", valStart);
          if (valEnd == -1) {
            valEnd = document.cookie.length;
          }
          return document.cookie.substring(valStart, valEnd);
        }
      }
    }
    return defVal;
  },

  /**
   * @description Sets a cookie with a given name, value, and expiration time. It stores
   * the cookie in either session storage or local storage, depending on the value of
   * `days`.
   * 
   * @param { string } cookie - name of the cookie being set or updated in the documentation.
   * 
   * @param { string } val - value to be stored in the cookie.
   * 
   * @param { binary_expression } days - number of days that the cookie should be stored
   * for, with values of 0 indicating a session cookie, -1 meaning deletion, and any
   * other value specifying a specific storage time in milliseconds.
   */
  writeSetting(cookie,val,days=10*365) { // default days='forever', 0=session cookie, -1=delete
    if (window.chrome) {
      if (days==0) {
        sessionStorage.setItem(this.cookie_namespace+cookie,val);
      } else {
        localStorage.setItem(this.cookie_namespace+cookie,val);
      }
    } else {
      let date = new Date();
      date.setTime(date.getTime()+(days*24*60*60*1000));
      const expiration = days!=0 ? "expires="+date.toGMTString()+";" : "";
      document.cookie = this.cookie_namespace + cookie + "=" +
                        val + "; SameSite=Lax;" + expiration + "path=/";
    }
  },

  /**
   * @description Removes a setting from local or session storage based on the namespace
   * and cookie provided.
   * 
   * @param { string } cookie - cookie to be erased from local or session storage.
   */
  eraseSetting(cookie) {
    if (window.chrome) {
      if (localStorage.getItem(this.cookie_namespace+cookie)) {
        localStorage.removeItem(this.cookie_namespace+cookie);
      } else if (sessionStorage.getItem(this.cookie_namespace+cookie)) {
        sessionStorage.removeItem(this.cookie_namespace+cookie);
      }
    } else {
      this.writeSetting(cookie,'',-1);
    }
  },
}
