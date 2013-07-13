/**
 * S3 REST用の共通クラス
 */
public class S3RestCommon {
    
    /**
     * Access Key Id
     */
    public String AWSAccessKeyId {get; private set;}
    
    /**
     * Access Key Secret
     */
    private String AWSAccessKeySecret {get; private set;}
    
    /**
     * バケット名
     */
    public String bucketName {get; private set;}
    
    /**
     * POST FORM用のポリシー
     */
    public String formPolicy {get; private set;}
    
    /**
     * コンストラクタ
     * @param keyId AWS_ACCESS_KEY_ID
     * @param secret AWS_ACCESS_KEY_SECRET
     * @param bucketName バケット名
     */
    public S3RestCommon (String keyId, String secret, String bucketName) {
        this.AWSAccessKeyId = keyId;
        this.AWSAccessKeySecret = secret;
        this.bucketName = bucketName;
    }
    
    /**
     * base64エンコードされたPOST FORM用のポリシー
     */
    public String getEncodedFormPolicy() {
        return EncodingUtil.base64Encode(Blob.valueOf(this.formPolicy));
    }
    
    /**
     * POST FORM用の各パラメータを含むDTOを生成
     */
    public S3.FormKeys getFormKeys(String formattedexpire, String redirectUrl) {
        this.formPolicy = '{ "expiration": "'+formattedexpire+'","conditions": [ {"bucket": "'+
                            this.bucketName +'" } ,{ "acl": "public-read" },' +
                            '{"success_action_redirect": "' + redirectUrl + '"},' +
                            '["starts-with", "$key", ""] ]}';
        
        S3.FormKeys fk = new S3.FormKeys();
        fk.formattedexpire = formattedexpire;
        fk.redirectUrl = redirectUrl;
        fk.formSignature = this.getFormSignature();
        fk.policy = this.getEncodedFormPolicy();
        fk.AWSAccessKeyID = this.AWSAccessKeyId;
        return fk;
    }
    
    /**
     * バケット名を設定する
     * @param bucket バケット名
     */
    public void setBucketName(String bucket) {
        this.bucketName = bucket;
    }
    
    /**
     * オブジェクト一覧取得
     */
    public List<S3.BucketObject> listBucketObject(Map<String, String> params) {
        return this.parseListObjectsResponse(this.callRestAPI('GET', null, '', '/', params, '', null));
    }
    
    /**
     * オブジェクト単体削除
     */
    public String deleteBucketObject(String deleteKey, Map<String, String> params) {
        return this.callRestAPI('DELETE', null, '', '/' + deleteKey, params, '', null);
    }
    
    /**
     * オブジェクト単体アップロード
     */
    public String postFile(String key, Blob file, Map<String, String> params) {
        Map<String, String> extHeader = new Map<String, String>{
            'Content-Length' => String.valueOf(file.size()),
            'x-amz-acl' => 'public-read'
        };
        
        return this.callRestAPI('PUT', file.toString(), '', '/' + key, params, '', extHeader);
    }
    
    /**
     * AWSの基本RESTコールアウト
     * 
     */
    public String callRestAPI(
        String method, 
        String body, 
        String contentType, 
        String resource,
        Map<String, String> paramGET,
        String contentMd5,
        Map<String, String> extHeader
    ) {
        DateTime dt = DateTime.now();
        HttpRequest req = new HttpRequest();
        req.setHeader('Host', this.bucketName + '.s3.amazonaws.com');
        req.setHeader('Date', this.getDateTime(dt));
        req.setHeader('Authorization','AWS ' + this.AWSAccessKeyId + ':' + this.getRestSignature(method, contentMd5, contentType, this.getDateTime(dt), extHeader, resource));
        
        if (!String.isBlank(contentType)) {
            req.setHeader('Content-Type', contentType);
        }
        
        if (!String.isBlank(contentMd5)) {
            req.setHeader('Content-MD5', contentMd5);
        }
        
        if (extHeader != null) {
            for (String key : extHeader.keySet()) {
                req.setHeader(key, extHeader.get(key));
            }
        }
        
        String endpoint = 'https://' + this.bucketName + '.s3.amazonaws.com' + resource;
        if (!String.isBlank(Utility.getParam(paramGET))) {
        	endpoint += '?' + Utility.getParam(paramGET);
        }
        req.setEndpoint(endpoint);
        req.setMethod(method);
        if(!String.isBlank(body)){
            req.setBody(body);
        }
        
        Http http = new Http();
        HTTPResponse res = http.send(req);
        system.debug(res.getBody());
        return res.getBody();
    }
    
    /**
     * REST用のsignature作成
     */
    private String getRestSignature(
        String httpVerb, 
        String contentMd5, 
        String contentType, 
        String dt, 
        Map<String, String> extHeader,
        String canonicalizedResource    
    ) {
        String canonicalizedAmzHeader = '';
        if (extHeader != null) {
            for (String key : extHeader.keySet()) {
                if (key.toLowerCase().indexOf('x-amz-') == -1) {
                    continue;
                }
                canonicalizedAmzHeader += key.toLowerCase() + ':' + extHeader.get(key) + Constants.LF;
            }
        }
        
        String stringToSign = httpVerb + Constants.LF 
                            + Utility.nullToBlank(contentMd5) + Constants.LF
                            + Utility.nullToBlank(contentType) + Constants.LF 
                            + dt + Constants.LF 
                            + canonicalizedAmzHeader
                            + '/' + this.bucketName + canonicalizedResource;
        return EncodingUtil.base64Encode(
            Crypto.generateMac(
                'HMacSHA1', 
                Blob.valueOf(stringToSign),
                Blob.valueOf(this.AWSAccessKeySecret)
            )
        );
    }
    
    /**
     * フォーマットされた日付文字列を取得
     */
    private String getDateTime(DateTime dt) {
        return dt.format('EEE, dd MMM yyyy HH:mm:ss ') + '+0900';
    }
    
    /**
     * リストのレスポンスをパース
     */
    private List<S3.BucketObject> parseListObjectsResponse(String res) {
        List<S3.BucketObject> objList = new List<S3.BucketObject>();
        Xmlstreamreader reader = new Xmlstreamreader(res);
        while (reader.hasNext()) {
            if (reader.getEventType() == XmlTag.START_ELEMENT) {
                if ('contents' == reader.getLocalName()) {
                    S3.BucketObject obj = parseS3Object(reader);
                    objList.add(obj);
                }
            }
            reader.next();
        }
        
        return objList;
        
    }
    
    /**
     * S3オブジェクトにパースしてListに格納
     */
    //ToDo もっとスマートにできればする
    private S3.BucketObject parseS3Object(XmlStreamReader reader) {
        S3.BucketObject obj = new S3.BucketObject();
        while (reader.hasNext()) {
            if (reader.getEventType() == XmlTag.START_ELEMENT) {
                if (reader.getLocalName() == 'key') {
                    reader.next();
                    obj.key = reader.getText();
                } else if (reader.getLocalName() == 'lastmodified' ) {
                    reader.next();
                    obj.lastModified = reader.getText();
                } else if (reader.getLocalName() == 'size' ) {
                    reader.next();
                    obj.size = reader.getText();
                } else if (reader.getLocalName() == 'owner' ) {
                    while (reader.hasNext()) {
                        if (reader.getEventType() == XmlTag.START_ELEMENT) {
                            if (reader.getLocalName() == 'displayname') {
                                reader.next();
                                obj.ownername = reader.getText();
                                break;
                            }
                        }
                        reader.next();
                    }
                }
            } else if (reader.getEventType() == XmlTag.END_ELEMENT) {
                if (reader.getLocalName() == 'contents') {
                    break;
                }
            }
            reader.next();
        }
        return obj;
    }
    
    /**
     * POST(form) Signatureを生成
     * @return POST(form) Signature
     */
    public String getFormSignature() {
        return EncodingUtil.base64Encode(
            Crypto.generateMac(
                'HMacSHA1', 
                Blob.valueOf(this.getEncodedFormPolicy()),
                Blob.valueOf(AWSAccessKeySecret)
            )
        );
    }
    
    /**
     * 複数件削除
     */
    public List<S3.DeleteResult> multipleDelete(List<String> deleteKeyList, Map<String, String> params) {
        Xmlstreamwriter writer = new Xmlstreamwriter();
        writer.writeStartDocument('UTF-8', '1.0');
        writer.writeStartElement('', 'Delete', '');
        
        writer.writeStartElement('', 'Quiet', '');
        writer.writeCharacters('false');
        writer.writeEndElement();
        
        for (String key : deleteKeyList) {
            writer.writeStartElement('', 'Object', '');
            
            writer.writeStartElement('','Key','');
            writer.writeCharacters(key);
            writer.writeEndElement();
            
            writer.writeEndElement();
        }
        
        writer.writeEndElement();
        writer.writeEndDocument();
        String xmlBody = writer.getXmlString();
        writer.close();
        Map<String, String> extHeader = new Map<String, String>{
            'Content-Length' => String.valueOf(Blob.valueOf(xmlBody).size())
        };
        String res = this.callRestAPI('POST', xmlBody, 'application/xml', '/?delete', params, this.getBase64EncodedMD5(xmlBody), extHeader);
        
        return this.parseDeleteResult(res);
    }
    
    /**
     * base64エンコードされたMD5ハッシュ値を取得
     */
    public String getBase64EncodedMD5(String target) {
        return EncodingUtil.base64Encode(Crypto.generateDigest('MD5', Blob.valueOf(target)));
    }
    
    /**
     * DeleteResultのパース
     * @param res レスポンスのXML文字列
     * @return List<S3.DeleteResult> S3.DeleteResultにパースしたリスト
     */
    //ToDo もっとスマートにできればする
    public List<S3.DeleteResult> parseDeleteResult(String res) {
        List<S3.DeleteResult> droList = new List<S3.DeleteResult>();
        Xmlstreamreader reader = new Xmlstreamreader(res);
        while (reader.hasNext()) {
            if (reader.getEventType() == XmlTag.START_ELEMENT) {
                if (reader.getLocalName().toLowerCase() == 'deleted') {
                    reader.next(); //'<key>aaa</key>';
                    reader.next(); //'aaa'
                    
                    S3.DeleteResult dro = new S3.DeleteResult();
                    dro.isSuccess = true;
                    dro.key = reader.getText();
                    droList.add(dro);
                } else if (reader.getLocalName().toLowerCase() == 'error') {
                    reader.next();
                    S3.DeleteResult dro = new S3.DeleteResult();
                    dro.isSuccess = false;
                    while (reader.hasNext()) {
                        if (reader.getEventType() == XmlTag.START_ELEMENT) {
                            String localName = reader.getLocalName().toLowerCase();
                            reader.next();
                            if (localName == 'key') {
                                dro.key = reader.getText();
                            } else if (localName == 'code') {
                                dro.code = reader.getText();
                            } else if (localName == 'message') {
                                dro.message = reader.getText();
                            }
                        }
                        reader.next();
                    }
                    droList.add(dro);
                }
            }
            reader.next();
        }
        return droList;
    }
    
    
}