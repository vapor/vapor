// MIT License

// Copyright (c) 2019 François Colas

// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:

// The above copyright notice and this permission notice shall be included in all
// copies or substantial portions of the Software.

// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
// SOFTWARE.
#include "multipartparser.h"

#include <string.h>

#define CR '\r'
#define LF '\n'
#define SP ' '
#define HT '\t'
#define HYPHEN '-'

#define CALLBACK_NOTIFY(NAME)                           \
    if (callbacks->on_##NAME != NULL) {                 \
        if (callbacks->on_##NAME(parser) != 0)          \
            goto error;                                 \
    }

#define CALLBACK_DATA(NAME, P, S)                       \
    if (callbacks->on_##NAME != NULL) {                 \
        if (callbacks->on_##NAME(parser, P, S) != 0)    \
            goto error;                                 \
    }

enum state {
    s_preamble,
    s_preamble_hy_hy,
    s_first_boundary,
    s_header_field_start,
    s_header_field,
    s_header_value_start,
    s_header_value,
    s_header_value_cr,
    s_headers_done,
    s_data,
    s_data_cr,
    s_data_cr_lf,
    s_data_cr_lf_hy,
    s_data_boundary_start,
    s_data_boundary,
    s_data_boundary_done,
    s_data_boundary_done_cr_lf,
    s_data_boundary_done_hy_hy,
    s_epilogue,
};

/* Header field name as defined by rfc 2616. Also lowercases them.
 *     field-name   = token
 *     token        = 1*<any CHAR except CTLs or tspecials>
 *     CTL          = <any US-ASCII control character (octets 0 - 31) and DEL (127)>
 *     tspecials    = "(" | ")" | "<" | ">" | "@"
 *                  | "," | ";" | ":" | "\" | DQUOTE
 *                  | "/" | "[" | "]" | "?" | "="
 *                  | "{" | "}" | SP | HT
 *     DQUOTE       = <US-ASCII double-quote mark (34)>
 *     SP           = <US-ASCII SP, space (32)>
 *     HT           = <US-ASCII HT, horizontal-tab (9)>
 */
static const char header_field_chars[256] = {
/*  0 nul   1 soh   2 stx   3 etx   4 eot   5 enq   6 ack   7 bel   */
    0,      0,      0,      0,      0,      0,      0,      0,
/*  8 bs    9 ht    10 nl   11 vt   12 np   13 cr   14 so   15 si   */
    0,      0,      0,      0,      0,      0,      0,      0,
/*  16 dle  17 dc1  18 dc2  19 dc3  20 dc4  21 nak  22 syn  23 etb  */
    0,      0,      0,      0,      0,      0,      0,      0,
/*  24 can  25 em   26 sub  27 esc  28 fs   29 gs   30 rs   31 us   */
    0,      0,      0,      0,      0,      0,      0,      0,
/*  32 sp   33 !    34 "    35 #    36 $    37 %    38 &    39 '    */
    0,      '!',    0,      '#',    '$',    '%',    '&',    '\'',
/*  40 (    41 )    42 *    43 +    44 ,    45 -    46 .    47 /    */
    0,      0,      '*',    '+',    0,      '-',    '.',    0,
/*  48 0    49 1    50 2    51 3    52 4    53 5    54 6    55 7    */
    '0',    '1',    '2',    '3',    '4',    '5',    '6',    '7',
/*  56 8    57 9    58 :    59 ;    60 <    61 =    62 >    63 ?    */
    '8',    '9',    0,      0,      0,      0,      0,      0,
/*  64 @    65 A    66 B    67 C    68 D    69 E    70 F    71 G    */
    0,      'A',    'B',    'C',    'D',    'E',    'F',    'G',
/*  72 H    73 I    74 J    75 K    76 L    77 M    78 N    79 O    */
    'H',    'I',    'J',    'K',    'L',    'M',    'N',    'O',
/*  80 P    81 Q    82 R    83 S    84 T    85 U    86 V    87 W    */
    'P',    'Q',    'R',    'S',    'T',    'U',    'V',    'W',
/*  88 X    89 Y    90 Z    91 [    92 \    93 ]    94 ^    95 _    */
    'X',    'Y',    'Z',     0,     0,      0,      '^',    '_',
/*  96 `    97 a    98 b    99 c    100 d   101 e   102 f   103 g   */
    '`',    'a',    'b',    'c',    'd',    'e',    'f',    'g',
/*  104 h   105 i   106 j   107 k   108 l   109 m   110 n   111 o   */
    'h',    'i',    'j',    'k',    'l',    'm',    'n',    'o',
/*  112 p   113 q   114 r   115 s   116 t   117 u   118 v   119 w   */
    'p',    'q',    'r',    's',    't',    'u',    'v',    'w',
/*  120 x   121 y   122 z   123 {   124 |   125 }   126 ~   127 del */
    'x',    'y',    'z',    0,      '|',     0,     '~',    0
};

void multipartparser_init(multipartparser* parser, const char* boundary)
{
    memset(parser, 0, sizeof(*parser));

    strncpy(parser->boundary, boundary, sizeof(parser->boundary));
    parser->boundary_length = strlen(parser->boundary);

    parser->state = s_preamble;
}

void multipartparser_callbacks_init(multipartparser_callbacks* callbacks)
{
    memset(callbacks, 0, sizeof(*callbacks));
}

size_t multipartparser_execute(multipartparser* parser,
                               multipartparser_callbacks* callbacks,
                               const char* data,
                               size_t size)
{
    const char*   mark;
    const char*   p;
    unsigned char c;

    for (p = data; p < data + size; ++p) {
        c = *p;

reexecute:
        switch (parser->state) {

            case s_preamble:
                if (c == HYPHEN)
                    parser->state = s_preamble_hy_hy;
                // else ignore everything before first boundary
                break;

            case s_preamble_hy_hy:
                if (c == HYPHEN)
                    parser->state = s_first_boundary;
                else
                    parser->state = s_preamble;
                break;

            case s_first_boundary:
                if (parser->index == parser->boundary_length) {
                    if (c != CR)
                        goto error;
                    parser->index++;
                    break;
                }
                if (parser->index == parser->boundary_length + 1) {
                    if (c != LF)
                        goto error;
                    CALLBACK_NOTIFY(body_begin);
                    CALLBACK_NOTIFY(part_begin);
                    parser->index = 0;
                    parser->state = s_header_field_start;
                    break;
                }
                if (c == parser->boundary[parser->index]) {
                    parser->index++;
                    break;
                }
                goto error;

            case s_header_field_start:
                if (c == CR) {
                    parser->state = s_headers_done;
                    break;
                }
                parser->state = s_header_field;
                // fallthrough;

            case s_header_field:
                mark = p;
                while (p != data + size) {
                    c = *p;
                    if (header_field_chars[c] == 0)
                        break;
                    ++p;
                }
                if (p > mark) {
                    CALLBACK_DATA(header_field, mark, p - mark);
                }
                if (p == data + size) {
                    break;
                }
                if (c == ':') {
                    parser->state = s_header_value_start;
                    break;
                }
                goto error;

            case s_header_value_start:
                if (c == SP || c == HT) {
                    break;
                }
                parser->state = s_header_value;
                // fallthrough;

            case s_header_value:
                mark = p;
                while (p != data + size) {
                    c = *p;
                    if (c == CR) {
                        parser->state = s_header_value_cr;
                        break;
                    }
                    ++p;
                }
                if (p > mark) {
                    CALLBACK_DATA(header_value, mark, p - mark);
                }
                break;

            case s_header_value_cr:
                if (c == LF) {
                    parser->state = s_header_field_start;
                    break;
                }
                goto error;

            case s_headers_done:
                if (c == LF) {
                    CALLBACK_NOTIFY(headers_complete);
                    parser->state = s_data;
                    break;
                }
                goto error;

            case s_data:
                mark = p;
                while (p != data + size) {
                    c = *p;
                    if (c == CR) {
                        parser->state = s_data_cr;
                        break;
                    }
                    ++p;
                }
                if (p > mark) {
                    CALLBACK_DATA(data, mark, p - mark);
                }
                break;

            case s_data_cr:
                if (c == LF) {
                    parser->state = s_data_cr_lf;
                    break;
                }
                CALLBACK_DATA(data, "\r", 1);
                parser->state = s_data;
                goto reexecute;

            case s_data_cr_lf:
                if (c == HYPHEN) {
                    parser->state = s_data_cr_lf_hy;
                    break;
                }
                CALLBACK_DATA(data, "\r\n", 2);
                parser->state = s_data;
                goto reexecute;

            case s_data_cr_lf_hy:
                if (c == HYPHEN) {
                    parser->state = s_data_boundary_start;
                    break;
                }
                CALLBACK_DATA(data, "\r\n-", 3);
                parser->state = s_data;
                goto reexecute;

            case s_data_boundary_start:
                parser->index = 0;
                parser->state = s_data_boundary;
                // fallthrough;

            case s_data_boundary:
                if (parser->index == parser->boundary_length) {
                    parser->index = 0;
                    parser->state = s_data_boundary_done;
                    goto reexecute;
                }
                if (c == parser->boundary[parser->index]) {
                    parser->index++;
                    break;
                }
                CALLBACK_DATA(data, parser->boundary, parser->index);
                parser->state = s_data;
                goto reexecute;

            case s_data_boundary_done:
                if (c == CR) {
                    parser->state = s_data_boundary_done_cr_lf;
                    break;
                }
                if (c == HYPHEN) {
                    parser->state = s_data_boundary_done_hy_hy;
                    break;
                }
                goto error;

            case s_data_boundary_done_cr_lf:
                if (c == LF) {
                    CALLBACK_NOTIFY(part_end);
                    CALLBACK_NOTIFY(part_begin);
                    parser->state = s_header_field_start;
                    break;
                }
                goto error;

            case s_data_boundary_done_hy_hy:
                if (c == HYPHEN) {
                    CALLBACK_NOTIFY(part_end);
                    CALLBACK_NOTIFY(body_end);
                    parser->state = s_epilogue;
                    break;
                }
                goto error;

            case s_epilogue:
                // Must be ignored according to rfc 1341.
                break;
        }
    }
    return size;

error:
    return p - data;
}
