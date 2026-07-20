#include <stdio.h>
#include <stdlib.h>
#include <syslog.h>
#include <fcntl.h>
#include <unistd.h>
#include <string.h>
#include <errno.h>

int main(int argc, char *argv[])
{
    openlog("writer", LOG_PID, LOG_USER);

    if (argc != 3) {
        syslog(LOG_ERR, "Invalid number of arguments: expected 2, got %d", argc - 1);
        fprintf(stderr, "Usage: %s <writefile> <writestr>\n", argv[0]);
        closelog();
        return 1;
    }

    const char *writefile = argv[1];
    const char *writestr  = argv[2];

    syslog(LOG_DEBUG, "Writing %s to %s", writestr, writefile);

    int fd = open(writefile, O_WRONLY | O_CREAT | O_TRUNC, 0644);
    if (fd == -1) {
        syslog(LOG_ERR, "Failed to open file %s: %s", writefile, strerror(errno));
        fprintf(stderr, "Error: could not open file %s: %s\n", writefile, strerror(errno));
        closelog();
        return 1;
    }

    ssize_t len = (ssize_t)strlen(writestr);
    ssize_t written = write(fd, writestr, len);
    if (written == -1 || written != len) {
        syslog(LOG_ERR, "Failed to write to file %s: %s", writefile, strerror(errno));
        fprintf(stderr, "Error: could not write to file %s: %s\n", writefile, strerror(errno));
        close(fd);
        closelog();
        return 1;
    }

    close(fd);
    closelog();
    return 0;
}
