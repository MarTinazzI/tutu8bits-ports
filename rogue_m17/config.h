/* config.h do Rogue no M17 (spec 035, plano D-10): escrito a mao no lugar do gerado pelo configure (que procura a
 * ncurses). So o que o fonte usa com a glibc; a curses e a nossa (curses.h desta pasta). */
#define HAVE_SYS_TYPES_H 1
#define HAVE_SYS_TYPES 1
#define HAVE_PWD_H 1
#define HAVE_UNISTD_H 1
#define HAVE_STDLIB_H 1
#define HAVE_STRING_H 1
#define HAVE_LIMITS_H 1
#define HAVE_FCNTL_H 1
#define HAVE_SYS_STAT_H 1
#define HAVE_ARPA_INET_H 1
#define HAVE_GETUID 1
#define HAVE_GETGID 1
#define HAVE_GETPWUID 1
#define HAVE_GETPASS 1
#define HAVE_ERASECHAR 1
#define HAVE_KILLCHAR 1
#define HAVE_ESCDELAY 1
#define HAVE_MEMSET 1
#define HAVE_STRCHR 1
#define HAVE_STRERROR 1
#define HAVE_VPRINTF 1
#define STDC_HEADERS 1
#define RETSIGTYPE void

/* placar local (RF-08): relativo a pasta de trabalho (o lancar.sh entra em saves/jogos/rogue), sem trava, sem setgid */
#define SCOREFILE "rogue.scr"
#define ALLSCORES 1
#define NUMSCORES 10
#define NUMNAME "Ten"

#define PACKAGE_NAME "Rogue"
#define PACKAGE_TARNAME "rogue"
#define PACKAGE_VERSION "5.4.4"
#define PACKAGE_STRING "Rogue 5.4.4"
#define PACKAGE_BUGREPORT ""
