%{
#include<stdio.h>
#include<stdlib.h>
#include<ctype.h>
#include<string.h>
#include<stdbool.h>

int yylex();
extern int yyparse();
FILE* yyin;
void yyerror(const char* s);

//寄存器分配
int reg_alloc();
//寄存器释放
void reg_free(int reg);
//打印俩寄存器
void print_reg(int reg1, int reg2, int reg3);
//寻找变量
void findVar(char* varName,int* varNo);
//新建变量
void addVar(char* varName,int varValue);
//取变量
void loadVar(char* varName,int regName);
//保存变量
void saveVar(char* varName,int regName);


//寄存器
#define REG_NUM 16

//实现符号表
#define VAR_TABLE_LEN 6
#define VAR_NAME_LEN 30

char    var_name_table[VAR_TABLE_LEN][VAR_NAME_LEN] = {};   //符号表
double  var_value_table [VAR_TABLE_LEN] = {};   //符号值表
int     var_reg_table[VAR_TABLE_LEN] = {};   //寄存器表
int     var_num = 0;    //当前符号表中的变量个数
char*   reg_name_table[] = {"r0","r1","r2","r3","r4", 
                        "r5","r6","r7","r8","r9","r10","r11",
                        "r12","r13","r14","r15"};//寄存器表,共16个
bool    reg_used_table[14] = {false};//寄存器使用表
bool    reg_saved_table[14] = {false};//寄存器保存表
struct  expr{
    int ival;
    int regNo;
};

%}

%union{
    struct expr exprval ;
    int ival;
    char* chval;
}
// 运算符类型
%token<ival> NUMBER
%token ADD MINUS
%token MULT DIV
%token L_BRAC R_BRAC
%token QUIT
%token TYPE_INT

%token<chval> VARNAME 
%token ASSIGN
// 结合律与优先级
%left ADD MINUS
%left MULT DIV
%right UMINUS

// 开始符号与非终结符
%type<exprval> expr
%type<ival> stmt
%start lines
%%


lines   :       lines stmt ';'        //   { printf("\t\t VALUE = %d\n", $2); }
        |       lines ';'
        |       lines QUIT            { printf("Now exiting...\n");exit(0);}
        |       // 空串
        ;

stmt    :       VARNAME ASSIGN expr         { 
                                                int varNo;
                                                findVar($1,&varNo);
                                                if(varNo == -1){//未找到,退出
                                                    printf("Variable '%s' not defined, exiting...\n", $1);
                                                    exit(-1);
                                                }
                                                else//找到，打印语句
                                                {
                                                    $$ = var_value_table[varNo] = $3.ival;
                                                    if(var_reg_table[varNo] != $3.regNo){
                                                        printf("\tmov");
                                                        print_reg(var_reg_table[varNo], $3.regNo,-1);
                                                    }
                                                    if(!reg_saved_table[$3.regNo]) 
                                                        reg_free($3.regNo);
                                                }
                                            }
        |       TYPE_INT VARNAME ASSIGN expr{
                                                int varNo;
                                                findVar($2,&varNo);
                                                if(varNo == -1){//未找到,新建变量
                                                    addVar($2,$4.ival);
                                                    printf("\tmov");
                                                    print_reg(var_reg_table[var_num-1], $4.regNo,-1);
                                                    if(!reg_saved_table[$4.regNo]) 
                                                        reg_free($4.regNo);
                                                }
                                                else{
                                                    printf("Varialbe '%s' defined twice, exiting...\n",$2);
                                                    exit(-1);
                                                }
                                            }
        |       expr                        { $$ = $1.ival;reg_free($1.regNo);}
        ;

expr    :       expr ADD expr               { $$.ival=$1.ival+$3.ival;$$.regNo = $1.regNo;printf("\tadd"); print_reg($1.regNo, $1.regNo, $3.regNo);if(!reg_saved_table[$3.regNo]) reg_free($3.regNo);}
        |       expr MINUS expr             { $$.ival=$1.ival-$3.ival;$$.regNo = $1.regNo;printf("\tsub"); print_reg($1.regNo, $1.regNo, $3.regNo);if(!reg_saved_table[$3.regNo]) reg_free($3.regNo);}
        |       expr MULT expr              { $$.ival=$1.ival*$3.ival;$$.regNo = $1.regNo;printf("\tmul"); print_reg($1.regNo, $1.regNo, $3.regNo);if(!reg_saved_table[$3.regNo]) reg_free($3.regNo);}//假设可以使用乘法指令
        |       expr DIV expr               { $$.ival=$1.ival/$3.ival;$$.regNo = $1.regNo;printf("\tdiv"); print_reg($1.regNo, $1.regNo, $3.regNo);if(!reg_saved_table[$3.regNo]) reg_free($3.regNo);}//假设可以使用除法指令
        |       MINUS expr   %prec UMINUS   { $$.ival=-$2.ival; $$.regNo = $2.regNo; int temp = reg_alloc(); printf("\tmov %s, #0\n", reg_name_table[temp]);printf("\tsub");print_reg($$.regNo, temp, $$.regNo);if(!reg_saved_table[temp]) reg_free(temp);}//重新指定优先级，因为这里使用的是MINUS，要将优先级改为 UMINUS
        |       NUMBER                      { $$.ival=$1; $$.regNo = reg_alloc(); printf("\tmov %s, #%d\n", reg_name_table[$$.regNo],$1);}
        |       L_BRAC expr R_BRAC          { $$.ival=$2.ival;$$.regNo = $2.regNo;}
        |       VARNAME                     { 
                                                int varNo;
                                                findVar($1,&varNo);
                                                if(varNo == -1){
                                                    printf("Variable '%s' not defined, exiting...\n", $1);
                                                    exit(-1);
                                                }
                                                $$.ival = var_value_table[varNo];
                                                $$.regNo = var_reg_table[varNo];
                                            }
        ;

%%
//寄存器分配
int reg_alloc(){
    for(int i=0;i<14;i++){
        if(!reg_used_table[i]){
            reg_used_table[i] = true;
            return i;
        }
    }
    printf("No more registers available, exiting...\n");
    exit(0);
}

//寄存器释放
void reg_free(int reg){
    reg_used_table[reg] = false;
}

//打印俩寄存器
void print_reg(int reg1, int reg2, int reg3){
    if(reg3 == -1)
        printf(" %s, %s\n",reg_name_table[reg1],reg_name_table[reg2]);
    else
        printf(" %s, %s, %s\n",reg_name_table[reg1],reg_name_table[reg2],reg_name_table[reg3]);
}

//寻找变量
void findVar(char* varName,int* varNo){
    for(int i=0;i<var_num;i++){
        if(strcmp(var_name_table[i],varName)==0){
            *varNo = i;
            return;
        }
    }
    *varNo = -1; //未找到
}

//新建变量
void addVar(char* varName,int varValue){
    strcpy(var_name_table[var_num],varName);
    var_value_table[var_num] = varValue;
    var_reg_table[var_num] = reg_alloc();
    reg_saved_table[var_reg_table[var_num]] = true;
    var_num++;
}

// programs section

int yylex()
{
    int t;
    while(1){
        t=getchar();
        if(t==' '||t=='\t'||t=='\n'){
            // do noting
        }else if(isdigit(t)){
            double num = t - '0';
            t = getchar();

            while(isdigit(t)){  // 整数部分
                num = num*10 + t - '0';
                t = getchar();
            }
            yylval.ival = num;
            ungetc(t,stdin); //将多读的一个字符放回输入流
            return NUMBER;
        }
        else if(t=='+'){
            return ADD;
        }
        else if(t=='-'){
            return MINUS;
        }
        else if(t == '*'){
            return MULT;
        }
        else if(t == '/'){
            return DIV;
        }
        else if(t == '('){
            return L_BRAC;
        }
        else if(t == ')'){
            return R_BRAC;
        }
        else if(t == '='){
            return ASSIGN;
        }
        else if(isalpha(t)){
            char* tmp = malloc(VAR_NAME_LEN);
            tmp[0] = t;
            t = getchar();
            while(isalpha(t)){
                strcat(tmp,(char*)&t);
                t = getchar();
            }
            ungetc(t,stdin);
            if(strcmp(tmp,"int")==0)
                return TYPE_INT;
            if(strcmp(tmp,"q")==0){
                return QUIT;
            }
            yylval.chval = tmp;
            return VARNAME;
        }
        else{
            return t;
        }
    }
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