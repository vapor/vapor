/*    $OpenBSD: bcrypt.c,v 1.55 2015/09/13 15:33:48 guenther Exp $    */

/*
 * Copyright (c) 2014 Ted Unangst <tedu@openbsd.org>
 * Copyright (c) 1997 Niels Provos <provos@umich.edu>
 *
 * Permission to use, copy, modify, and distribute this software for any
 * purpose with or without fee is hereby granted, provided that the above
 * copyright notice and this permission notice appear in all copies.
 *
 * THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES
 * WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF
 * MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR
 * ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES
 * WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN
 * ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF
 * OR IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.
 */
/* This password hashing algorithm was designed by David Mazieres
 * <dm@lcs.mit.edu> and works as follows:
 *
 * 1. state := InitState ()
 * 2. state := ExpandKey (state, salt, password)
 * 3. REPEAT rounds:
 *      state := ExpandKey (state, 0, password)
 *    state := ExpandKey (state, 0, salt)
 * 4. ctext := "OrpheanBeholderScryDoubt"
 * 5. REPEAT 64:
 *     ctext := Encrypt_ECB (state, ctext);
 * 6. RETURN Concatenate (salt, ctext);
 *
 */

#include <sys/types.h>
#include "blf.h"
#include <ctype.h>
#include <errno.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "bcrypt.h"

int encode_base64(char *, const u_int8_t *, size_t);
int decode_base64(u_int8_t *, size_t, const char *);

// digests plaintext against the provided 16 byte salt
// loads a 24 byte digest into digest
// returns -1 if error
int bcrypt_digest(const uint8_t *plaintext,
                  size_t plaintext_len,
                  int cost,
                  const uint8_t salt[BCRYPT_SALT_SIZE],
                  uint8_t digest[BCRYPT_DIGEST_SIZE])
{
    blf_ctx state;
    uint32_t i, k;
    uint16_t j;
    u_int8_t minor;
    memcpy(digest, "OrpheanBeholderScryDoubt", BCRYPT_DIGEST_SIZE);
    u_int32_t cdata[BCRYPT_WORDS];

    if (cost < BCRYPT_MINLOGROUNDS || cost > 31) {
        return -1;
    }
    uint32_t rounds = 1U << cost;

    Blowfish_initstate(&state);
    Blowfish_expandstate(&state, salt, BCRYPT_MAXSALT, plaintext, plaintext_len);
    for (k = 0; k < rounds; k++) {
        Blowfish_expand0state(&state, plaintext, plaintext_len);
        Blowfish_expand0state(&state, salt, BCRYPT_MAXSALT);
    }

    /* This can be precomputed later */
    j = 0;
    for (i = 0; i < BCRYPT_WORDS; i++) {
        cdata[i] = Blowfish_stream2word(digest, 4 * BCRYPT_WORDS, &j);
    }

    /* Now do the encryption */
    for (k = 0; k < 64; k++) {
        blf_enc(&state, cdata, BCRYPT_WORDS / 2);
    }

    for (i = 0; i < BCRYPT_WORDS; i++) {
        digest[4 * i + 3] = cdata[i] & 0xff;
        cdata[i] = cdata[i] >> 8;
        digest[4 * i + 2] = cdata[i] & 0xff;
        cdata[i] = cdata[i] >> 8;
        digest[4 * i + 1] = cdata[i] & 0xff;
        cdata[i] = cdata[i] >> 8;
        digest[4 * i + 0] = cdata[i] & 0xff;
    }

    explicit_bzero(&state, sizeof(state));
    explicit_bzero(cdata, sizeof(cdata));
    return 0;
}

/*
 * internal utilities
 */
static const u_int8_t Base64Code[] =
"./ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789";

static const u_int8_t index_64[128] = {
    255, 255, 255, 255, 255, 255, 255, 255, 255, 255,
    255, 255, 255, 255, 255, 255, 255, 255, 255, 255,
    255, 255, 255, 255, 255, 255, 255, 255, 255, 255,
    255, 255, 255, 255, 255, 255, 255, 255, 255, 255,
    255, 255, 255, 255, 255, 255, 0, 1, 54, 55,
    56, 57, 58, 59, 60, 61, 62, 63, 255, 255,
    255, 255, 255, 255, 255, 2, 3, 4, 5, 6,
    7, 8, 9, 10, 11, 12, 13, 14, 15, 16,
    17, 18, 19, 20, 21, 22, 23, 24, 25, 26, 27,
    255, 255, 255, 255, 255, 255, 28, 29, 30,
    31, 32, 33, 34, 35, 36, 37, 38, 39, 40,
    41, 42, 43, 44, 45, 46, 47, 48, 49, 50,
    51, 52, 53, 255, 255, 255, 255, 255
};
#define CHAR64(c)  ( (c) > 127 ? 255 : index_64[(c)])

/*
 * read buflen (after decoding) bytes of data from b64data
 */
int
decode_base64(u_int8_t *buffer, size_t len, const char *b64data)
{
    u_int8_t *bp = buffer;
    const u_int8_t *p = (u_int8_t *)b64data;
    u_int8_t c1, c2, c3, c4;

    while (bp < buffer + len) {
        c1 = CHAR64(*p);
        /* Invalid data */
        if (c1 == 255)
            return -1;

        c2 = CHAR64(*(p + 1));
        if (c2 == 255)
            return -1;

        *bp++ = (c1 << 2) | ((c2 & 0x30) >> 4);
        if (bp >= buffer + len)
            break;

        c3 = CHAR64(*(p + 2));
        if (c3 == 255)
            return -1;

        *bp++ = ((c2 & 0x0f) << 4) | ((c3 & 0x3c) >> 2);
        if (bp >= buffer + len)
            break;

        c4 = CHAR64(*(p + 3));
        if (c4 == 255)
            return -1;
        *bp++ = ((c3 & 0x03) << 6) | c4;

        p += 4;
    }
    return 0;
}

/*
 * Turn len bytes of data into base64 encoded data.
 * This works without = padding.
 */
int
encode_base64(char *b64buffer, const u_int8_t *data, size_t len)
{
    u_int8_t *bp = (u_int8_t *)b64buffer;
    const u_int8_t *p = data;
    u_int8_t c1, c2;

    while (p < data + len) {
        c1 = *p++;
        *bp++ = Base64Code[(c1 >> 2)];
        c1 = (c1 & 0x03) << 4;
        if (p >= data + len) {
            *bp++ = Base64Code[c1];
            break;
        }
        c2 = *p++;
        c1 |= (c2 >> 4) & 0x0f;
        *bp++ = Base64Code[c1];
        c1 = (c2 & 0x0f) << 2;
        if (p >= data + len) {
            *bp++ = Base64Code[c1];
            break;
        }
        c2 = *p++;
        c1 |= (c2 >> 6) & 0x03;
        *bp++ = Base64Code[c1];
        *bp++ = Base64Code[c2 & 0x3f];
    }
    *bp = '\0';
    return 0;
}
