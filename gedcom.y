%{
#define _GNU_SOURCE 1
#include <glib.h>
#include <sys/stat.h>
#include <sys/types.h>
#include <stdio.h>
#include <string.h>
extern int yylex();
extern int yylineno;
extern char *yytext;
int yyerror();

static char* assetPath = "assets";
static char* indPath = "assets/individuals";
static char* famPath = "assets/families";
static char* cssPath = "assets/gedcom.css";

char* sb;
GArray* paramBuilder;
FILE* indexhtml;
FILE* thisFD;

// Estrutura que representa cada individuo
typedef struct Individual{
  int id;
  GString* name;
  GArray* marrs;
}Individual;

// Estrutura que representa cada familia
typedef struct Family{
    int id;
    int h;
    int w;
    GArray* chld;
}Family;

Individual* thisI;
Family* thisF;
Individual* submitter;

//Hashtable com os ids dos individuos
GHashTable* inds;
//Hashtable com os ids das familias
GHashTable* fams;

// Função que cria uma nova página por Individuo/Familia
void newPage(char* filePath,char* fileName,char* payload,char noBody){
    char* pat=NULL;
    char* ret;
    asprintf(&pat,"%s/%s.html",filePath,fileName);
    FILE* fd=fopen(pat,"w");
    asprintf(&ret,"<div><a href=\"../../index.html\" ><b>RETURN TO INDEX\n\n</b></a> %s </div>"," ");
    if(noBody=='n') fprintf(fd,"<!DOCTYPE html>\n<html>\n<head>\n%s\n\nIndividual %s\n<link rel=\"stylesheet\" type=\"text/css\" href=\"../gedcom.css\"></head>\n<body>\n<ul>%s</ul>\n</body></html>",ret,fileName+1,payload);
    else fprintf(fd,"<!DOCTYPE html>\n<html>\n<head>\n%s\n\nFamily %s\n<link rel=\"stylesheet\" type=\"text/css\" href=\"../gedcom.css\"></head>\n<body>\n%s<ul>\n</ul>\n",ret,fileName+1,payload);

    fclose(fd);
    free(pat);
    sb="";
}

// Funcão que retorna uma string formatada com o nome do casamento relativo á familia idFam
char* printMarriage(int idFam){
    char* ret=""; int i=0;
    if (!g_hash_table_contains (fams,GINT_TO_POINTER(idFam) )) {asprintf(&ret," UNDEFINED %d",idFam);return ret;}
    
    Family* f =g_hash_table_lookup(fams,GINT_TO_POINTER(idFam));
    if(f->h){
        asprintf(&ret,"%s",(( (Individual*) g_hash_table_lookup(inds,GINT_TO_POINTER(f->h)))->name)->str);
        i=1;
        }
    if(f->w)
        if(i)
        asprintf(&ret,"%s & %s",ret, (((Individual*) g_hash_table_lookup(inds,GINT_TO_POINTER(f->w)))->name)->str);
        else
        asprintf(&ret,"%s",(((Individual*) g_hash_table_lookup(inds,GINT_TO_POINTER(f->w)))->name)->str);
    return ret;
}

//Função que cria uma nova instancia de individuo para preencher
void resetI(){
    thisI = malloc(sizeof(Individual));
    thisI->marrs=g_array_new(FALSE,FALSE,sizeof(int));
}
//Função que cria uma nova instancia de familia para preencher
void resetF(){
    thisF= malloc(sizeof(Family));
    thisF->chld =g_array_new(FALSE,TRUE,sizeof(int));
    thisF->h=0;
    thisF->w=0;
}
//Função que inicializa as estruturas
void init(){
    inds = g_hash_table_new(g_direct_hash,g_direct_equal);
    fams = g_hash_table_new(g_direct_hash,g_direct_equal);
    paramBuilder =g_array_new(FALSE,TRUE,sizeof(GString));
    resetI();
    resetF();
}

//Função que regista um Individuo completamente parsed
void registerI(int i,char* payload){
    char* identifier;
    asprintf(&identifier,"I%d",i);
    newPage(indPath,identifier,payload,'n');
    thisI->id=i;
    g_hash_table_insert(inds,GINT_TO_POINTER(thisI->id),thisI);
    resetI();
}

//Função que regista uma Familia completamente parsed
void registerF(int i,char* payload){
    char* identifier;
    asprintf(&identifier,"F%d",i);
    
    newPage(famPath,identifier, payload,'y');
    thisF->id = i;
    g_hash_table_insert(fams,GINT_TO_POINTER(thisF->id),thisF);
    resetF();
}

//Função que regista o autor do ficheiro
void registerS(int i,char* payload){
    char* identifier;
    asprintf(&identifier,"S%d",i);
    newPage(assetPath,identifier,payload,'n');
    thisI->id=i;
    submitter = thisI;
    resetI();
}

// Função que combina o tipo de evento com cada parametro numa string
void buildEvent(char** dd, char* event){
    for(int i=0;i<paramBuilder->len-1;i+=2){
        GString head= g_array_index(paramBuilder,GString,i);
        GString tail= g_array_index(paramBuilder,GString,i+1);
        asprintf(dd,"<li><b>%s%s : &nbsp</b>%s</li>",head.str,event,tail.str);
    }
    g_array_free(paramBuilder, TRUE);
    paramBuilder =g_array_new(FALSE,TRUE,sizeof(GString));
}

// Macro para obter o nome de um individuo
char* getInd(int id){
    return  (((Individual*)g_hash_table_lookup(inds,GINT_TO_POINTER(id)))->name->str);
}

// Função que cria a árvore de descendencia para cada familia
void buildTree( int id, FILE* file){
    Family* f=(Family*) g_hash_table_lookup(fams,GINT_TO_POINTER(id));
    GArray* breadthI = f->chld;
    int foundDesc=0;
    int flag =1;
    for(int j=0;j<breadthI->len;j++){
       int childId = g_array_index(breadthI,int,j);
       Individual* child  = g_hash_table_lookup(inds,GINT_TO_POINTER(childId));
       GArray* marr = child->marrs;
       foundDesc += marr->len; 
       if(flag&&foundDesc){flag=0; fprintf(file,"<ul>\n");}
        for(int k=0;k<marr->len;k++){
            int marrID= g_array_index(marr,int,k);

            if (!g_hash_table_contains (fams,GINT_TO_POINTER(marrID))) return;

            fprintf(file,"<li>\n<a href=\"F%d.html\">%s</a>\n",marrID,printMarriage(marrID));
            buildTree(marrID,file);
            fprintf(file,"</li>\n");
        }
    }
    if(foundDesc>0) fprintf(file,"</ul>\n");
}

//Função de comparação de ids
gint compareId(gconstpointer a,gconstpointer b){return(GPOINTER_TO_INT(a)-GPOINTER_TO_INT(b));}
%}

%union{
    int ival;
    char cval;
    char* sval;
}

%token BIRT DEAT BURI CHR MARR DIV BAPL BAPM BARM BASM EVEN 
%token ADOP HUSB WIFE CHIL FAMC FAMS
%token AGE TITL NAME DEBUG DEST SOUR ALIA  EMAIL FORM NATI NATU NOTE OCCU SEX
%token INIT END PLAC DATE CONT CAUS CITY CONC
%token CHAR GEDC LANG FIL VERS CORP ADDR PHON CTRY
%token SUBM AUTH

%token <ival> fam indi sub
%token <sval> nam cont
%type  <sval> FileStruct Corp CorpList Sd SdList Continuation Tag FamElem ContextlessTag Cont Tags TagList Famx Event Family FamList HeaderLines HeaderLine HeaderTag

%%
Gedcom: INIT Header Body END 
      ;

Cont:  Cont Continuation        {asprintf(&$$,"%s %s",$1,$2);}
    |                           {asprintf(&$$,"%s"," ");}
    ;

Continuation: CONT cont         {asprintf(&$$,"\n%s",$2);}
            | CONC cont         {asprintf(&$$,"%s",$2);}
            ;

Header: HeaderLine HeaderLines  {fprintf(indexhtml,"%s %s",$1,$2);}
      ;

HeaderLines: HeaderLine HeaderLines {asprintf(&$$,"%s %s",$1,$2);}
           |                        {$$=" ";}
           ;

HeaderLine: HeaderTag           {$$=$1;}
          ;

HeaderTag: SOUR cont SdList     {asprintf(&$$,"<li><b>Source</b>: %s <ul>%s</ul></li>",$2,$3);}
         | DEST cont SdList     {asprintf(&$$,"<li><b>Destinantion</b>: %s <ul>%s</ul></li>",$2,$3);}
         | DATE cont Cont       {asprintf(&$$,"<li><b>Date</b>:%s %s</li>",$2,$3);}
         | FileStruct Cont      {asprintf(&$$,"%s %s</li>",$1,$2);}
         | SUBM sub             {asprintf(&$$,"<li> <b>Submitter :</b> <a href=\"assets/S%d.html\">S%d</a></li>", $2,$2);}
         | AUTH cont            {asprintf(&$$,"<li><b>Author</b>:%s</li>",$2);}
         | GEDC SdList          {asprintf(&$$,"<li>\n<b>Gedcom</b> <ul>%s</ul></li>",$2);}
         ;

SdList: Sd SdList           {asprintf(&$$,"%s %s",$1,$2);}
      |                        {$$= " ";}
      ;

Sd: NAME nam Cont            {asprintf(&$$,"<li><b>Name:&nbsp</b>%s %s</li>",$2,$3);}
  | VERS cont Cont           {asprintf(&$$,"<li><b>Version:&nbsp</b>%s %s</li>",$2,$3);}
  | CORP cont Cont CorpList  {asprintf(&$$,"<li><b>Corporation:&nbsp</b>%s %s</li>%s",$2,$3,$4);}
  | FORM cont                {asprintf(&$$,"<li><b>File Format</b>:%s</li>",$2);}
  ; 

CorpList: Corp Cont CorpList  {asprintf(&$$,"%s %s %s",$1,$2,$3);}
        |                     {$$=" ";}
        ;

Corp: ADDR cont               {asprintf(&$$,"<li><b>Corporation Address:&nbsp</b>%s",$2);}
    | PHON cont               {asprintf(&$$,"<li><b>Corporation Phone:&nbsp</b>%s",$2);}
    ;

FileStruct: FIL cont          {asprintf(&$$,"<li><b>Original File:&nbsp</b>%s",$2);}
          | CHAR cont         {asprintf(&$$,"<li><b>Encoding:&nbsp</b>%s",$2);}
          | LANG cont         {asprintf(&$$,"<li><b>Language:&nbsp</b>%s",$2);}
          ;

Body: BodyLine BodyList
    ;

BodyList: BodyLine BodyList
        |
        ;

BodyLine: TagId               {;}
        ;

Tags: Tag TagList             {asprintf(&$$,"%s %s",$1,$2);}
    ;

TagList: Tag TagList          {asprintf(&$$,"%s %s",$1,$2);}
       |                      {asprintf(&$$,"%s"," ");}
       ;

Tag: ContextlessTag Cont      {asprintf(&$$,"%s %s\n</li>",$1,$2);}
   | Event                    {asprintf(&$$,"%s\n",$1);}
   ;

ContextlessTag: NAME nam      {thisI->name=g_string_new($2);asprintf(&$$,"<li><b>Name:&nbsp</b>%s",$2);}
              | TITL cont     {asprintf(&$$,"<li><b>Title:&nbsp</b>%s",$2);}
              | NATI cont     {asprintf(&$$,"<li><b>Nationality:&nbsp</b>%s",$2);}
              | NOTE cont     {asprintf(&$$,"<li><b>Note:&nbsp</b>%s",$2);}
              | NATU cont     {asprintf(&$$,"<li><b>Naturality:&nbsp</b>%s",$2);}
              | ALIA cont     {asprintf(&$$,"<li><b>Alias:&nbsp</b>%s",$2);}
              | EMAIL cont    {asprintf(&$$,"<li><b>Email:&nbsp</b>%s",$2);}
              | OCCU cont     {asprintf(&$$,"<li><b>Occupation:&nbsp</b>%s",$2);}
              | Famx          {$$=$1;}
              | FamElem       {$$=$1;}
              | ADDR cont     {thisI->name=g_string_new($2);asprintf(&$$,"<li><b>Address:&nbsp</b>%s\n</li>",$2);}
              | PHON cont     {thisI->name=g_string_new($2);asprintf(&$$,"<li><b>Phone Number:&nbsp</b>%s",$2);}
              | DEBUG         {;}
              | DEST cont     {asprintf(&$$,"<li><b>Dest:&nbsp</b>%s",$2);}
              | AGE cont      {asprintf(&$$,"<li><b>Age:&nbsp</b>%s",$2);}
              | SEX cont      {asprintf(&$$,"<li><b>Sex:&nbsp</b>%s",$2);}
              ;

Famx: FAMS fam                {g_array_append_val(thisI->marrs,$2);asprintf(&$$,"<li><b>Spouse in:&nbsp</b><a href=\"../families/F%d.html\" >F%d</a></li>",$2,$2);}
    | FAMC fam                {asprintf(&$$,"<li><b>Child in:&nbsp</b><a href=\"../families/F%d.html\" >F%d</a></li>",$2,$2);}
    ;

Event: DEAT EventTail        {buildEvent(&$$," of Death");}
     | BIRT EventTail        {buildEvent(&$$," of Birth");}
     | BURI EventTail        {buildEvent(&$$," of Burial");}
     | CHR  EventTail        {buildEvent(&$$," of Christning");}
     | BAPL  EventTail       {buildEvent(&$$," of Mormon Baptism");}
     | BAPM  EventTail       {buildEvent(&$$," of Christian Baptism");}
     | BARM  EventTail       {buildEvent(&$$," of Bar Mitzvah");}
     | BASM  EventTail       {buildEvent(&$$," of Bat Mitzvah");}
     | EVEN cont EventTail   {char* c;asprintf(&c," of %s",$2);buildEvent(&$$,c);}
     ;
EventTail: Param  ParamList 
         ;

ParamList: Param  ParamList 
         |  
         ; 

Param:  PLAC cont            {g_array_append_val(paramBuilder,*g_string_new("Place"));g_array_append_val(paramBuilder,*g_string_new($2));}
     |  CITY cont            {g_array_append_val(paramBuilder,*g_string_new("City"));g_array_append_val(paramBuilder,*g_string_new($2));}
     |  CTRY cont            {g_array_append_val(paramBuilder,*g_string_new("Country"));g_array_append_val(paramBuilder,*g_string_new($2));}
     |  DATE cont            {g_array_append_val(paramBuilder,*g_string_new("Date"));g_array_append_val(paramBuilder,*g_string_new($2));}
     |  CAUS cont            {g_array_append_val(paramBuilder,*g_string_new("Cause"));g_array_append_val(paramBuilder,*g_string_new($2));}
     ;

TagId: fam Family            {registerF($1,$2);}            
     | indi Tags             {registerI($1,$2);}
     | sub  Tags             {registerS($1,$2);}
     ;
     
Family: FamElem  FamList     {asprintf(&$$,"%s %s",$1,$2);}
      ;

FamList: FamElem  FamList    {asprintf(&$$,"%s %s",$1,$2);}
       |                     {$$=" ";}
       ;

FamElem: HUSB indi           {thisF->h=$2;asprintf(&$$,"<li> <b>Husband:&nbsp</b> <a href=\"../individuals/I%d.html\">%s</a> \n</li>",$2,getInd($2));}        
      | WIFE indi            {thisF->w=$2;asprintf(&$$,"<li> <b>Wife:&nbsp</b> <a href=\"../individuals/I%d.html\">  %s</a>\n</li>",$2,getInd($2));}  
      | CHIL indi            {g_array_append_val(thisF->chld,$2);asprintf(&$$,"<li> <b>Biological child:&nbsp</b> <a href=\"../individuals/I%d.html\"> %s</a>\n</li>",$2,getInd($2));}  
      | MARR ParamList       {buildEvent(&$$,"of Marriage");}
      | DIV cont             {asprintf(&$$,"<li><b>Divorce :&nbsp</b> %s </li>\n",$2);}
      | ADOP indi            {g_array_append_val(thisF->chld,$2);asprintf(&$$,"<li> <b>Adoptive child:&nbsp</b> <a href=\"../individuals/I%d.html\"> %s</a>\n</li>",$2,getInd($2));}  
      ;
%%



int main(){
    init();
    mkdir(assetPath,0777);
    mkdir(indPath,0777);
    mkdir(famPath,0777);
    indexhtml =fopen("index.html","w");
    
    fprintf(indexhtml, "%s","<!DOCTYPE html><html><head> <link rel=\"stylesheet\" type=\"text/css\" href=\"index.css\"></head><body>");
    if (indexhtml == NULL) {
            printf("Erro ao abrir o ficheiro\n");
        return 1;}
    yyparse();
    GList* indList= g_list_sort(g_hash_table_get_keys(inds), compareId);
    GList* baseList= g_list_sort(g_hash_table_get_keys(fams), compareId);
    fprintf(indexhtml,"<div class=\"row\"><div class=\"column\"><ul>\n");
    while(baseList!= NULL){
        char* path;
        int fm =GPOINTER_TO_INT(baseList->data);
        asprintf(&path,"assets/families/F%d.html",fm);
        fprintf(indexhtml,"<li><a href=\"%s\">Family %d</a></li>",path, fm);
        FILE* f= fopen(path,"a");
        fprintf(f,"<div class=\"tree\"><ul>\n<li>\n<a>%s</a>", printMarriage(fm));
        buildTree(fm,f);
        fprintf(f,"</li></ul></div></body></html>");
        fclose(f);
        baseList=g_list_next(baseList);
    }
    fprintf(indexhtml,"</ul></div><div class=\"column\"><ul>\n");

    while(indList!= NULL){
        char* pat;
        int nd =GPOINTER_TO_INT(indList->data);
        asprintf(&pat,"assets/individuals/I%d.html",nd);
        fprintf(indexhtml,"<li><a href=\"%s\">Individual %d :%s</a></li>",pat, nd,(((Individual*) g_hash_table_lookup(inds,indList->data))->name)->str);
        indList=g_list_next(indList);
    }

    fprintf(indexhtml,"</ul></div></div>");
    fprintf(indexhtml, "</body></html>");
    FILE* to =fopen(cssPath,"w");
    FILE* from = fopen("gedcom.css","r");
    char ch;
    while((ch = fgetc(from)) != EOF)
        fputc(ch, to);
    fclose(to);
    fclose(from);
    printf("DONE\n");
    return 0;
    
}

int yyerror(){
    printf("Erro Sintático ou Léxico na linha: %d, com o texto: %s#\n", yylineno, yytext);
    return 0;
}

