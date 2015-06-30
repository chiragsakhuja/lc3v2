%{

#include <cstdio>
#include <string>
#include <cstring>
#include <algorithm>

#include "tokens.h"
#include "parser.hpp"

int stringToInt(const char *str);
void yyerror(const char *);
Token * makeToken(const char *tok, int type);

int rowNum = 0, colNum = 0;

%}

%option noyywrap case-insensitive pointer

LE      [\r\n]
NLE     [^\r\n]
WS      [ \n\r\t]
NWS     [^ \n\r\t]
NDEL    [^ ,:.\n\r\t]
BDIG    [0-1]
DIG     [0-9]
HDIG    [0-9a-f]

%%

{LE}+                   { colNum = 0; if(strlen(yytext) > 1 || yytext[0] != '\r') { rowNum++; } return NEWLINE; }

[,]                     { colNum += strlen(yytext); return COMMA; }
[.]                     { colNum += strlen(yytext); return DOT  ; }
[:]                     { colNum += strlen(yytext); return COLON; }

{WS}+                   { colNum += strlen(yytext); }
(;|("//")){NLE}*        { colNum += strlen(yytext); }

0?b{BDIG}+              { yylval.tok = makeToken(yytext, NUM)   ; colNum += strlen(yytext); return NUM   ; }
#?{DIG}+                { yylval.tok = makeToken(yytext, NUM)   ; colNum += strlen(yytext); return NUM   ; }
0?x{HDIG}+              { yylval.tok = makeToken(yytext, NUM)   ; colNum += strlen(yytext); return NUM   ; }
{NDEL}+|['"]{NLE}*['"]  { yylval.tok = makeToken(yytext, STRING); colNum += strlen(yytext); return STRING; }

%%

Token * makeToken(const char *tok, int type)
{
    Token *ret = nullptr;

    if(type == STRING) {
        std::string *tokStr = new std::string(tok);
        std::transform(tokStr->begin(), tokStr->end(), tokStr->begin(), ::tolower);
        ret = new Token(tokStr);
    } else {
        ret = new Token(stringToInt(tok));
    }

    ret->rowNum = rowNum;
    ret->colNum = colNum;
    ret->length = strlen(tok);

    return ret;
}

int stringToInt(const char *str)
{
    if(str[0] == '0') { str++; }

    std::string conv = std::string(str).substr(1);

    switch(str[0]) {
        case 'b': return std::stoi(conv, 0, 2) ; break;
        case 'x': return std::stoi(conv, 0, 16); break;
        case '#': return std::stoi(conv)       ; break;
        default : return std::stoi(str)        ; break;
    }
}