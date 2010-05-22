#include <limits.h>
#include <stdlib.h>
#include <stdio.h>
#include <string.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <unistd.h>
#include <errno.h>

#ifdef	__APPLE__
#define LDLP "DYLD_LIBRARY_PATH"
#else
#define LDLP "LD_LIBRARY_PATH"
#endif

/* Needed for execve */
extern char **environ;

int main( int argc,
          char** argv )
{
  char *fullname;   /* 'fullname' is used to store the absolute path to the
                       tool being executed; it serves as a base to compute
                       the realname of that tool, and the directory holding
                       our runtime libraries */
  char *realname;   /* 'realname' is the real name of the tool, that is what
                       the wrapper is currently impersonating */
  char *basedir;    /* 'libdir' contains our runtime libraries */

  char *lastslash;  /* Temporary variables now */
  char *ldlibpath;
  size_t len;
  int execve_ret;

  /* Avoid the warning-treated-as-error: "error: unused parameter 'argc'" */
  len = argc;

  /* In case we have a relative or absolute pathname (ie. contains a slash),
   * then realpath wll work. But if the tool was found in the PATH, realpath
   * won't work, and we'll have to search ourselves.
   * This if{}else{} block allocates memory for fullname. */
  if( strchr( argv[0], '/' ) ) {
    fullname = (char*) malloc( PATH_MAX * sizeof(char) );
    if( ! realpath( argv[0], fullname ) ) {
      perror( "tool wrapper" );
      exit( 1 );
    }
  } else {
    char *path;
    char *mypath;
    char *colon;
    char *testname;
    struct stat st;

    fullname = NULL;
    colon = mypath = path = strdup( getenv( "PATH" ) );
    while( colon ) {
      colon = strchr( mypath, ':' );
      if( colon ) {
        *colon = '\0';
      }
      testname = strdup( mypath );
      testname = (char*) realloc( testname,   strlen( testname )
                                            + strlen( argv[0] )
                                            + 2 * sizeof(char) );
      memset( testname + strlen( testname ),
              0,
              strlen( argv[0] ) + 2 * sizeof(char) );
      strcat( testname, "/" );
      strcat( testname, argv[0] );
      if( stat( testname, &st ) == 0 ) {
        /* OK, exists. Is it a regular file, or a
         * symlink, which the current user may execute? */
        if( S_ISREG( st.st_mode ) && ! access( testname, X_OK || R_OK ) ) {
          fullname = strdup( testname );
          break;
        }
      }
      free( testname );
      mypath = colon + 1;
    }
    free( path );
    if( ! fullname ) {
      fprintf( stderr, "tool wrapper: %s: command not found\n", argv[0] );
      exit( 1 );
    }
  }

  /* Duplicate my own name to add the 'dot' to tool name */
  realname = strdup( fullname );
  realname = (char*) realloc( realname, strlen( realname) + 2 * sizeof(char) );
  realname[ strlen( realname ) + 1 ] = '\0';

  /* Add the dot after the last '/' */
  lastslash = strrchr( realname, '/' );
  memmove( lastslash + 1, lastslash, strlen( lastslash ) );
  *( lastslash + 1 ) = '.';

  /* Compute the basedir of the tool */
  basedir = strdup( fullname );
  lastslash = strrchr( basedir, '/' );
  *lastslash = '\0';
  lastslash = strrchr( basedir, '/' );
  *lastslash = '\0';

  /* Append '/lib' */
  len = strlen( basedir );
  basedir = (char*) realloc( basedir, len + 5 );
  *( basedir + len ) = '\0';
  strcat( basedir, "/lib" );

  /* Now add the directory with our runtime libraries to the
     front of the library search path, LD_LIBRARY_PATH */
  ldlibpath = getenv(LDLP);
  if( ldlibpath ) {
    basedir = (char*) realloc( basedir,   strlen( basedir )
                                        + strlen( ldlibpath )
                                        + 2 * sizeof(char) );
    strcat( basedir, ":" );
    strcat( basedir, ldlibpath );
  }

  if( setenv( LDLP, basedir, 1 ) ) {
    errno = ENOMEM;
    perror( "tool wrapper" );
    exit( 1 );
  }

  /* Execute the real tool, now */
  execve_ret = execve( realname, argv, environ );

  /* In case something went wrong above, print a
     diagnostic message, and exit with error code 1 */
  perror( "tool wrapper" );
  return 1;
}
