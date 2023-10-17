%{
/*********************************************
YACC file
基础程序
Date:2023/10/2
实现SysY到汇编的编译器，支持声明变量、常量，赋值，连续表达式
**********************************************/
#include<stdio.h>
#include<stdlib.h>
#include<ctype.h>
#include<string.h>
#include<stdbool.h>

int yylex();
extern int yyparse();
FILE* yyin;
void yyerror(const char* s);
// 符号表操作函数声明
struct symbol* findSymbol(char* name);
void addSymbol(char* name, double value, bool isConst, bool isAllocated);

#define MAX_NAME_LEN 20
// 符号表
struct symbol{
    char *name;
    double value;
    struct symbol *next;
    bool isConst;  // 是否是常量
    bool isAllocated;  // 是否已经赋值
};
// 头指针
struct symbol *symbolTable = NULL;
int GLOBAL_REG = 0;  // 寄存器编号


%}

%union{
    int dval;  // 变量值 -> 改成int 简化汇编代码
    char *name;  // 变量名
}

// 给每个符号定义一个单词类别
%token<dval> NUMBER
%token<name> TYPE
%token<name> CONSTANT
%token AND OR
%token ADD MINUS
%token MUL DIV
%token LPAREN RPAREN
%token QUIT // 退出程序
%token<name> IDENTIFIER // 标识符
%token ASSIGN // 赋值符号
%token NOT

%left ASSIGN
%left AND OR
%left ADD MINUS
%left MUL DIV
%right NOT
%right UMINUS   


// 还得给非终结符定义类型
%type<dval> expr
%type<dval> stmt
%start lines

%%

// 使用;作为一行的结束符
lines   :       lines stmt ';' { printf("----------\n"); GLOBAL_REG = 0;}  // 一个语句完了，寄存器编号归零
        |       lines ';'
        |       lines QUIT  { exit(0); }
        |
        ;
// 语句     
stmt    :       expr    {   $$=$1; }
        |       IDENTIFIER ASSIGN expr  {   $$=$3;      // 赋值语句
                                            struct symbol *entry=findSymbol($1);  // 必须声明过
                                            if(entry==NULL){
                                                yyerror("undeclared variable");
                                            }
                                            addSymbol($1,$3,false,true);  // 添加到符号表
                                            printf("ldr R1, =%s\n",$1);
                                            printf("str R0, [R1]\n");
                                        }
        |       TYPE IDENTIFIER         {   $$=0;       // 声明变量
                                            addSymbol($2,0,false,false);  // 添加到符号表
                                            //printf("ldr R1, =%s\n",$2);  // 不赋初值
                                            //printf("mov R0 #0\n");
                                            //printf("str R0, [R1]\n");
                                        }
        |       TYPE IDENTIFIER ASSIGN expr {   $$=$4;      // 声明变量且带初值
                                                addSymbol($2,$4,false,true);  // 添加到符号表
                                                printf("ldr R1, =%s\n",$2);
                                                printf("str R0, [R1]\n");
                                            }
        |       CONSTANT TYPE IDENTIFIER ASSIGN expr {  $$=$5;  // 声明常量且带初值
                                                        addSymbol($3,$5,true,true);  // 添加到符号表
                                                        printf("ldr R1, =%s\n",$3);
                                                        printf("str R0, [R1]\n");
                                                }
        |       CONSTANT TYPE IDENTIFIER    {   $$=0;       // 声明常量
                                                addSymbol($3,0,true,false);  // 添加到符号表
                                            }
        ;
// 完善表达式的规则
expr    :       expr ADD expr   {   
                                    $$=$1+$3; 
                                    printf("ADD R0 R0 R1\n");
                                    GLOBAL_REG -= 1;  // 为了连续表达式
                                }
        |       expr MINUS expr {   
                                    $$=$1-$3;
                                    printf("SUB R0 R0 R1\n");
                                    GLOBAL_REG -= 1;
                                }
        |       expr MUL expr   {   
                                    $$=$1*$3;
                                    printf("MUL R0 R0 R1\n"); 
                                    GLOBAL_REG -= 1;
                                }
        |       expr DIV expr   {   
                                    $$=$1/$3;
                                    printf("DIV R0 R0 R1\n");
                                    GLOBAL_REG -= 1; 
                                }
        |       expr AND expr   {   
                                    $$=$1&&$3;
                                    printf("AND R0 R0 R1\n");
                                    GLOBAL_REG -= 1;
                                }
        |       expr OR expr    {   
                                    $$=$1||$3;
                                    printf("OR R0 R0 R1\n");
                                    GLOBAL_REG -= 1;
                                }
        |       NOT expr        {   
                                    $$=!$2;
                                    printf("CMP R%d #0\n",GLOBAL_REG-1);
                                    printf("MOVNE R%d #0\n",GLOBAL_REG-1);
                                    printf("MOVEQ R%d #1\n",GLOBAL_REG-1);
                                }
        |       LPAREN expr RPAREN   { $$=$2; }
        |       MINUS expr %prec UMINUS {   $$=-$2;
                                            printf("NEG R%d R%d\n",GLOBAL_REG-1,GLOBAL_REG-1);
                                        }  // %prec提升优先级
        |       NUMBER          {   $$=$1;
                                    printf("MOV R%d %d\n",GLOBAL_REG,$1);
                                    GLOBAL_REG++;  // 每个值由NUMBER来打印
                                }
        |       IDENTIFIER      {   struct symbol *entry=findSymbol($1);
                                    if(entry==NULL){
                                        yyerror("undeclared variable");
                                    }
                                    if(!entry->isAllocated){
                                        yyerror("variable not allocated");
                                    }
                                    $$=entry->value;
                                    printf("ldr R%d, [%s]\n",GLOBAL_REG,$1);
                                    GLOBAL_REG++;  // 变量等价于NUMBER
                                }
        ;

%%

// programs section

int yylex()  // 词法分析器
{
    int t;
    while(1){
        t = getchar();
        if(t==' '||t=='\t'||t=='\n'){  // 忽略空白符
            // do noting
        }
        else if(isdigit(t)){
            // 解析多位数字返回数字类型 
            yylval.dval = 0;  // yylval存储和传递词法单元的值
            while(isdigit(t)){
                yylval.dval = yylval.dval * 10 + (t - '0');
                t = getchar();
            }
            // 识别小数点后面的数字->浮点数汇编指令，麻烦了
            //if(t == '.'){
                //t = getchar();
                //int i = 0.1;
                //while(isdigit(t)){
                    //yylval.dval = yylval.dval + (t - '0') * i;
                    //i = i / 10;
                    //t = getchar();
                //}
            //}
            // 将读出的多余字符再次放回到缓冲区去
            ungetc(t,stdin);
            return NUMBER;
        }
        else if(t=='+'){
            return ADD;
        }
        else if(t=='-'){
            return MINUS;
        }
        else if(t=='*'){
            return MUL;
        }
        else if(t=='/'){
            return DIV;
        }
        else if(t=='('){
            return LPAREN;
        }
        else if(t==')'){
            return RPAREN;
        }
        else if(t=='='){  // 赋值符号
            return ASSIGN;
        }
        else if(t=='&'){  // 逻辑与
            t = getchar();
            if(t!='&'){
                yyerror("unknown character");
            }
            return AND;
        }
        else if(t=='|'){  // 逻辑或
            t = getchar();
            if(t!='|'){
                yyerror("unknown character");
            }
            return OR;
        }
        else if(t=='!'){  // 逻辑非
            return NOT;
        }
        else if(isalpha(t)){  // 识别标识符
            char *p = yylval.name = malloc(MAX_NAME_LEN);
            *p++ = t;
            int len = 1;
            // 读取标识符
            while(isalnum(t=getchar())){
                *p++ = t;
                if(++len>=MAX_NAME_LEN){
                    yyerror("name too long");
                }
            }
            ungetc(t,stdin);  // 将多读的字符放回缓冲区
            if(len==3&&strcmp(yylval.name,"int")==0){
                return TYPE;
            }
            if(len==5&&strcmp(yylval.name,"const")==0){
                return CONSTANT;
            }
            *p = '\0';  // 字符串结束符
            return IDENTIFIER;
        }
        else if(t=='#'){  // 退出程序
            return QUIT;
        }
        else{  // ;
            return t;
        }
    }
}

struct symbol* findSymbol(char* name){
    // 在符号表中查找一个符号
    struct symbol *s;
    for(s=symbolTable;s!=NULL;s=s->next){  // 遍历符号表
        if(strcmp(s->name,name)==0){
            return s;
        }
    }
    return NULL;  // 没有找到
}

void addSymbol(char* name, double value, bool isConst, bool isAllocated){
    // 向符号表中添加一个符号
    struct symbol *s = findSymbol(name);
    if(s!=NULL){  // 如果已经存在
        if(s->isConst&&s->isAllocated){  // 常量不能被赋值
            yyerror("constant cannot be assigned");
        }
        s->value = value;
        s->isAllocated = true;
    }
    // 否则创建一个新的符号
    s = malloc(sizeof(struct symbol));
    s->name = strdup(name);
    s->value = value;
    s->next = symbolTable;
    s->isConst = isConst;
    s->isAllocated = isAllocated;
    symbolTable = s;
}

int main(void)
{
    yyin=stdin;
    do{
        yyparse();
    }while(!feof(yyin));
    return 0;
}
void yyerror(const char* s){
    fprintf(stderr,"Parse error: %s\n",s);
    exit(1);
}