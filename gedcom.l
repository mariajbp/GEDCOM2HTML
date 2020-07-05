%option stack yylineno 
%{
#define _GNU_SOURCE 1   
#include "y.tab.h"
#include <string.h>
#include <stdio.h>
char* sb;
%}

num [0-9]
tag ([A-Z]{3}[A-Z]?|@([IF]|(S(UB)?M?))[0-9]+@)
sep [ ]+

%x line tags content name tagid  debug  nochan

%%
0{sep}HEAD[\n \t\r]*        {printf("INIT\n");return INIT;}
0{sep}TRLR[\n \t\r]*        {return END;}
{num}+/{sep}{tag}           {yy_push_state(tags);}
\n                          ;

<line,tags>{sep}            ;

<tags>\n                    {yy_pop_state();}
<tags>NAME{sep}             {sb=strdup("");yy_push_state(name);return NAME; }

<tags>FILE{sep}             {sb=strdup("");yy_push_state(content);return FIL;}
<tags>CHAR{sep}             {sb=strdup("");yy_push_state(content);return CHAR;}
<tags>GEDC{sep}?            {yy_pop_state();return GEDC;}
<tags>LANG{sep}             {sb=strdup("");yy_push_state(content);return LANG;}
<tags>CORP{sep}             {sb=strdup("");yy_push_state(content);return CORP;}
<tags>ADDR{sep}             {sb=strdup("");yy_push_state(content);return ADDR;}
<tags>PHON{sep}             {sb=strdup("");yy_push_state(content);return PHON;}
<tags>AUTH{sep}             {sb=strdup("");yy_push_state(content);return AUTH;}
<tags>EVEN{sep}?            {sb=strdup("");yy_push_state(content);return EVEN;}
<tags>EMAIL{sep}            {sb=strdup("");yy_push_state(content);return EMAIL;}
<tags>CTRY{sep}             {sb=strdup("");yy_push_state(content);return CTRY;}
<tags>CONC{sep}             {sb=strdup("");yy_push_state(content);return CONC;}
<tags>CITY{sep}             {sb=strdup("");yy_push_state(content);return CITY;}
<tags>ALIA{sep}             {sb=strdup("");yy_push_state(content);return ALIA;}
<tags>DIV{sep}              {sb=strdup("");yy_push_state(content);return DIV;}
<tags>SOUR{sep}             {sb=strdup("");yy_push_state(content);return SOUR;}
<tags>BIRT{sep}?            {yy_pop_state();return BIRT;}
<tags>DATE{sep}             {sb=strdup("");yy_push_state(content);return DATE;}

<tags>CAUS{sep}              {sb=strdup("");yy_push_state(content);return CAUS;}
<tags>DEAT{sep}?             {yy_pop_state();return DEAT;}
<tags>CHR{sep}?              {yy_pop_state();return CHR;}

<tags>BARM{sep}?             {yy_pop_state();return BARM;}
<tags>BASM{sep}?             {yy_pop_state();return BASM;}
<tags>BAPM{sep}?             {yy_pop_state();return BAPM;}
<tags>BAPL{sep}?             {yy_pop_state();return BAPL;}


<tags>VERS{sep}              {sb=strdup("");yy_push_state(content);return VERS;}
<tags>SEX{sep}               {sb=strdup("");yy_push_state(content);return SEX;}
<tags>OCCU{sep}              {sb=strdup("");yy_push_state(content);return OCCU;}
<tags>NOTE{sep}              {sb=strdup("");yy_push_state(content);return NOTE;}
<tags>NATI{sep}              {sb=strdup("");yy_push_state(content);return NATI;}
<tags>NATU{sep}              {sb=strdup("");yy_push_state(content);return NATU;}
<tags>DEST{sep}              {sb=strdup("");yy_push_state(content);return DEST;}
<tags>TITL{sep}              {sb=strdup("");yy_push_state(content);return TITL;}
<tags>FAMS{sep}@             {yy_push_state(tagid);return FAMS;}
<tags>FAMC{sep}@             {yy_push_state(tagid);return FAMC;}
<tags>CHAN{sep}?             yy_push_state(nochan);
<tags>AGE{sep}               {sb=strdup("");yy_push_state(content);return AGE;}
<tags>PLAC{sep}              {sb=strdup("");yy_push_state(content);return PLAC;}
<tags>{sep}@                 {yy_push_state(tagid);}
<tags>ADOP{sep}@             {yy_push_state(tagid);return ADOP;}
<tags>HUSB{sep}@             {yy_push_state(tagid);return HUSB;}
<tags>SUBM{sep}@             {yy_push_state(tagid);return SUBM;}
<tags>CHIL{sep}@             {yy_push_state(tagid);return CHIL;}
<tags>WIFE{sep}@             {yy_push_state(tagid);return WIFE;}
<tags>CONT{sep}              {sb=strdup("");yy_push_state(content);return CONT;}
<tags>BURI{sep}?             {yy_pop_state();return BURI;}
<tags>MARR{sep}?             {yy_pop_state();return MARR;}
<tags>@[a-zA-Z ]*[ \n\t\r]   {yy_pop_state();}
<tags>FORM{sep}              {sb=strdup("");yy_push_state(content);return FORM;}
<tags>.                      {yy_push_state(debug);}
<tags>{sep}/@[^ISF]          {yy_push_state(debug);}

<debug>.*                    {yy_pop_state();}

<nochan>\n             ;
<nochan>(DATE|TIME).*/\n     yy_pop_state();

<tagid>F[0-9]+               {yylval.ival=atoi(yytext+1);yy_pop_state();return fam;}
<tagid>I[0-9]+               {yylval.ival=atoi(yytext+1);yy_pop_state();return indi;}
<tagid>S[a-zA-Z]*[0-9]*      {if(atoi(yytext+1)==0)yylval.ival=1;else yylval.ival=atoi(yytext+1) ;yy_pop_state();return sub;}
    
<name>[^/_\n]*               {asprintf(&sb," %s%s",sb,yytext);}
<name>\/                     asprintf(&sb,"%s%s",sb, " ");
<name>_                      asprintf(&sb,"%s ",sb);
<name>[^/_\n]*/\n            {if(yyleng>0)  asprintf(&sb,"%s%s",sb, yytext); yylval.sval=sb;yy_pop_state();return nam;}


<content>[^\n_]              {asprintf(&sb,"%s%s",sb,yytext);}
<content>,/,                 ;
<content>_                   ;
<content>./\n                {asprintf(&sb,"%s%s",sb,yytext);yylval.sval=sb;yy_pop_state();return cont;}


{num}+{sep}_[^\n]*\n         ;
<*>.                         {}
<*><<EOF>>                   {printf("PROCESSING DATA...\n");return 0;}

%%
