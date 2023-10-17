%{
#include<stdio.h>
#include<stdlib.h>
#include<ctype.h>
#include<stdbool.h>
#include <locale.h>
#include <wchar.h>

int yylex();
extern int yyparse();
FILE* yyin;
void yyerror(const char* s);

#define epsilon L'\u03B5'

// 状态的定义
#define MAX_NEXT_STATE 100
#define MAX_STATE_SIZE 100
int CurrentState = 0;
struct edge     // 边
{
    wchar_t ch;
    struct state* nextState;
};
struct state    // 状态
{
    int id;
    struct edge nextEdge[MAX_NEXT_STATE];
    int nextNum;
};
struct expr // 表达式的值
{
    struct state* start;
    struct state* end;
};

/* 操控状态的函数 */
// 
void addEdge(struct state *s, wchar_t ch, struct state *nextState);
// 创建新的状态
struct state* newState(struct edge* nextEdge, int nextNum);
// 创建新的表达式
struct expr* newExprval(wchar_t ch);
struct expr* newExprvalSE(struct state* start,struct state* end);
// 连接两个表达式
struct expr* connectExprval(struct expr* expr1,struct expr* expr2);
// 闭包
struct expr* closureExprval(struct expr* expr);
// 或
struct expr* orExprval(struct expr* expr1,struct expr* expr2);
// 打印状态
void printState(struct state* s);
// 打印exprval
void printExprval(struct expr* expr);
%}

%union{
    wchar_t chval;
    struct expr* exprval;
}
// 运算符类型
%token OR
%token CLOSURE 
%token L_BRAC R_BRAC
%token QUIT
%token<chval> UNIT

// 结合律与优先级
%left OR        // 或
%left CONNECT    //  连接
%right CLOSURE   // 闭包

// 开始符号与非终结符
%type<exprval> expr
%type<exprval> unit
%type<exprval> unit_seq
%start lines
%%


lines   :       lines expr ';'                  { printExprval($2);CurrentState = 0; }
        |       lines QUIT                      { printf("Now exiting...\n");exit(0); }
        |       // 空串
        ;

expr    :       expr OR expr                    { $$ = orExprval($1,$3); free($1); free($3); }
        |       unit_seq                        { $$ = $1; }
        ;

unit_seq:       unit                            { $$ = $1; }
        |       unit_seq unit                   { $$ = connectExprval($1,$2); free($1); free($2); }
        ;

unit    :       UNIT                            { $$ = newExprval($1); }
        |       unit CLOSURE                    { $$ = closureExprval($1); free($1); }
        |       L_BRAC expr R_BRAC              { $$ = $2; }
        ;


%%

// programs section

int yylex()
{
    int t;
    while(1){
        t=getchar();
        if (t==' '||t=='\t'||t=='\n')
        {
            // do noting
        }
        else if (t == '|')
        {
            return OR;
        }
        else if (t == '*')
        {
            return CLOSURE;
        }
        else if (t == '(')
        {
            return L_BRAC;
        }
        else if (t == ')')
        {
            return R_BRAC;
        }
        else if (t == '?')
        {
            return QUIT;
        }
        else if (t == ';')
        {
            return t;
        }
        else{
            yylval.chval = t;
            return UNIT;
        }
    }
}
struct state* newState(struct edge* nextEdge, int nextNum)
{
    struct state* s = (struct state*)malloc(sizeof(struct state));
    s->id = CurrentState++;
    s->nextNum = nextNum;
    if (nextNum > 0)
    {
        for (int i = 0; i < nextNum; i++)
        {
            s->nextEdge[i] = nextEdge[i];
        }
    }
    else
    {
        s->nextEdge[0].nextState = NULL;
    }
    return s;
}

struct expr* newExprval(wchar_t ch)
{
    struct state* start = newState(NULL,0);
    struct state* end = newState(NULL,0);
    addEdge(start, ch, end);
    return newExprvalSE(start,end);
}

struct expr* newExprvalSE(struct state* start,struct state* end)
{
    struct expr* expr = (struct expr*)malloc(sizeof(struct expr));
    expr->start = start;
    expr->end = end;
    return expr;
}

void printState(struct state* s)
{
    setlocale(LC_ALL, "");  // 设置本地化环境
    
    bool stateUsed[MAX_STATE_SIZE] = {false};
    struct state* stateStack[MAX_STATE_SIZE/2];
    int size = 0;

    stateStack[size++] = s;

    FILE *fp = freopen("output.dot", "w", stdout);  //重定向
    if (fp == NULL)
    {
        printf("error opening file\n");
        exit(-1);
    }

    printf("digraph G {\n");
    while(size)
    {
        struct state* curState = stateStack[--size];
        
        stateUsed[curState->id] = true;
        if (curState->nextNum == 0)
            continue;

        for (int i = 0; i < curState->nextNum; i++)
        {
            printf("\t%d -> %d [label=\"%lc\"];\n", curState->id, curState->nextEdge[i].nextState->id, curState->nextEdge[i].ch);
        }

        for (int i = 0; i < curState->nextNum; i++)
        {
            if (!stateUsed[curState->nextEdge[i].nextState->id])
            {
                stateStack[size++] = curState->nextEdge[i].nextState;
            }
        }
    }
    printf("}\n");
    fclose(fp);
}

void printExprval(struct expr* expr)
{
    printState(expr->start);
}

struct expr* connectExprval(struct expr* expr1,struct expr* expr2)
{
    if (expr2 == NULL)
        return expr1;
    struct state *interS = expr1->end;
    struct state *interE = expr2->start;
    interS->nextNum = interE->nextNum;

    for (int i = 0; i< interE->nextNum; i++)
    {
        interS->nextEdge[i] = interE->nextEdge[i];
    }
    return newExprvalSE(expr1->start,expr2->end);
}

void addEdge(struct state *s, wchar_t ch, struct state *nextState)
{
    struct edge e;
    e.ch = ch;
    e.nextState = nextState;
    s->nextEdge[s->nextNum++] = e;
}

struct expr* closureExprval(struct expr* expr)
{
    struct state *start = expr->start;
    struct state *end = expr->end;

    struct state *new_start = newState(NULL, 0);
    struct state *new_end = newState(NULL, 0);

    addEdge(end, epsilon, start); //反向边
    addEdge(new_start, epsilon, start);
    addEdge(end, epsilon, new_end);
    addEdge(new_start, epsilon, new_end);
    return newExprvalSE(new_start, new_end);
}

struct expr* orExprval(struct expr* expr1,struct expr* expr2)
{
    struct state *start1 = expr1->start;
    struct state *end1 = expr1->end;
    struct state *start2 = expr2->start;
    struct state *end2 = expr2->end;

    struct state *new_start = newState(NULL, 0);
    struct state *new_end = newState(NULL, 0);

    addEdge(new_start, epsilon, start1);
    addEdge(new_start, epsilon, start2);
    addEdge(end1, epsilon, new_end);
    addEdge(end2, epsilon, new_end);

    return newExprvalSE(new_start, new_end);
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