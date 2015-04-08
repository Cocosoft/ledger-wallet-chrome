class @Coinkite

  API_BASE: "https://api.coinkite.com"
  CK_PATH: "0xb11e'/0xffaa001'"

  constructor: (api_key, secret) ->
    @apiKey = api_key
    @secret = secret
    @httpClient = new HttpClient(@API_BASE)

  getExtendedPublickey: (callback) ->
    try
      ledger.app.wallet.getExtendedPublicKey @CK_PATH, (key) =>
        @xpub = key._xpub58
        ledger.app.wallet.signMessageWithBitId @CK_PATH, "Coinkite", (signature) =>
          callback?({xpub: @xpub, signature: signature}, null)
    catch error
      callback?(null, error)

  getCosignData: (request, cosigner, callback) ->
    @request = request
    @cosigner = cosigner
    url = '/v1/co-sign/' + request + '/' + cosigner
    @_setAuthHeaders(url)
    @httpClient
      .do type: 'GET', url: url
      .then (data, statusText, jqXHR) =>
        callback?(data.signing_info, null)
      .fail (error, statusText) =>
        callback?(null, error)
      .done()

  cosignTransaction: (data, callback) ->
    inputs = data.inputs
    scripts = data.redeem_scripts
    tx = data.raw_unsigned_txn
    try
      transaction = Bitcoin.Transaction.deserialize(tx);
      ledger.app.wallet._lwCard.dongle.signP2SHTransaction_async(inputs, transaction, scripts, @CK_PATH)
      .then (result) =>
        url = '/v1/co-sign/' + @request + '/' + @cosigner + '/sign'
        @_setAuthHeaders(url)
        @httpClient
          .do type: 'PUT', url: url, dataType: 'json', contentType: 'application/json', data: { signatures: result }
          .then (data, statusText, jqXHR) =>
            callback?(data, null)
          .fail (error, statusText) =>
            callback?(null, error)
          .done()        
      .fail (error) =>
        callback?(null, error)
    catch error
      callback?(null, error)

  _setAuthHeaders: (endpoint) ->
    endpoint = endpoint.split('?')[0]
    ts = (new Date).toISOString()
    data = endpoint + '|' + ts
    @httpClient.setHttpHeader 'X-CK-Key', @apiKey
    @httpClient.setHttpHeader 'X-CK-Sign', CryptoJS.HmacSHA256(data, @secret).toString()
    @httpClient.setHttpHeader 'X-CK-Timestamp', ts