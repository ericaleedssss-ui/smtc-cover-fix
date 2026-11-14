// SPDX-License-Identifier: AGPL-3.0-only
package netease

import (
	"bytes"
	"crypto/aes"
	"crypto/cipher"
	"crypto/rand"
	"crypto/rsa"
	"crypto/x509"
	"encoding/base64"
	"encoding/json"
	"encoding/pem"
	"fmt"
	"math/big"
	"net/url"
	"slices"
	"strings"
	"sync"
)

// The public web client key used by the message and profile endpoints.
var webAPIKey = sync.OnceValue(func() *rsa.PublicKey {
	block, _ := pem.Decode([]byte(`-----BEGIN PUBLIC KEY-----
MIGfMA0GCSqGSIb3DQEBAQUAA4GNADCBiQKBgQDgtQn2JZ34ZC28NWYpAUd98iZ3
7BUrX/aKzmFbt7clFSs6sXqHauqKWqdtLkF2KexO40H1YTX8z2lSgBBOAxLsvakl
V8k4cBFK9snQXE9/DDaFt6Rr7iVZMldczhC0JNgTz+SHXT6CBHuX3e9SdB1Ua44
oncaTWz7OBGLbCiK45wIDAQAB
-----END PUBLIC KEY-----`))
	key, err := x509.ParsePKIXPublicKey(block.Bytes)
	if err != nil {
		panic(err)
	}
	return key.(*rsa.PublicKey)
})

func webAPICBC(b []byte, key string) []byte {
	block, _ := aes.NewCipher([]byte(key))
	n := aes.BlockSize - len(b)%aes.BlockSize
	padded := append(b, bytes.Repeat([]byte{byte(n)}, n)...)
	cipher.NewCBCEncrypter(block, []byte("0102030405060708")).CryptBlocks(padded, padded)
	return []byte(base64.StdEncoding.EncodeToString(padded))
}

func webAPI(path string, data map[string]any, out any) error {
	// Use the existing site session and request handling.
	data["csrf_token"] = ""
	if httpClient.Jar != nil {
		for _, c := range httpClient.Jar.Cookies(siteURL) {
			if c.Name == "__csrf" {
				data["csrf_token"] = c.Value
				break
			}
		}
	}
	body, err := json.Marshal(data)
	if err != nil {
		return err
	}
	var raw [8]byte
	_, err = rand.Read(raw[:])
	if err != nil {
		return err
	}
	secret := fmt.Sprintf("%x", raw)
	encrypted := webAPICBC(webAPICBC(body, "0CoJUm6Qyw8W8jud"), secret)
	reversed := []byte(secret)
	slices.Reverse(reversed)
	key := webAPIKey()
	k := new(big.Int).Exp(new(big.Int).SetBytes(reversed), big.NewInt(int64(key.E)), key.N)
	return post("/weapi/"+strings.TrimPrefix(path, "/api/"), url.Values{
		"params": {string(encrypted)}, "encSecKey": {fmt.Sprintf("%0*x", key.Size()*2, k)},
	}, out)
}
