/*
 * Eternal Darkness for the PlayStation 5 - what runs before the game's main.
 *
 * The game's main is the recomp's, so the console's start-up is a constructor:
 * standard error into klog and the shell's splash dismissed, the title's folder
 * as the working folder (the recomp finds generated/main.dol, dump/<id>.iso,
 * res/, saves/ and settings.ini there), and where SDL and Aurora keep their files.
 *
 * SPDX-License-Identifier: GPL-3.0-or-later
 */
#include <dirent.h>
#include <errno.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/stat.h>
#include <unistd.h>

#include <SDL3/SDL_stdinc.h>

#include "platform.h"

#define TITLE_DIR "/app0"
#define CACHE_DIR TITLE_DIR "/cache"

/* The shader caches the title ships (res/shader-cache, filled on a console by a
 * first start: ps5/tools/link-title.sh), for a console that has none yet: Dawn's
 * cache, where Aurora opens it, and the driver's folder. Without them a first
 * start compiles every render pipeline. Copied once: what is there, even half
 * of it, is the console's own from then on. */
static void
seed_file(const char *from, const char *to)
{
   char buffer[65536];
   size_t count;
   FILE *in = fopen(from, "rb");
   FILE *out = in != NULL ? fopen(to, "wb") : NULL;

   while (out != NULL && (count = fread(buffer, 1, sizeof(buffer), in)) > 0)
      fwrite(buffer, 1, count, out);
   if (out != NULL)
      fclose(out);
   if (in != NULL)
      fclose(in);
}

static void
seed_folder(const char *from, const char *to)
{
   char source[512], target[512];
   struct dirent *entry;
   struct stat status;
   DIR *folder = opendir(from);

   if (folder == NULL)
      return;
   mkdir(to, 0777);
   while ((entry = readdir(folder)) != NULL) {
      if (strcmp(entry->d_name, ".") == 0 || strcmp(entry->d_name, "..") == 0)
         continue;
      snprintf(source, sizeof(source), "%s/%s", from, entry->d_name);
      snprintf(target, sizeof(target), "%s/%s", to, entry->d_name);
      if (stat(source, &status) != 0)
         continue;
      if (S_ISDIR(status.st_mode))
         seed_folder(source, target);
      else
         seed_file(source, target);
   }
   closedir(folder);
}

static void
seed_shader_caches(void)
{
   struct stat status;

   if (stat(TITLE_DIR "/res/shader-cache/dawn_cache.db", &status) != 0)
      return;
   if (stat(CACHE_DIR "/dawn_cache.db", &status) != 0) {
      seed_file(TITLE_DIR "/res/shader-cache/dawn_cache.db", CACHE_DIR "/dawn_cache.db");
      fprintf(stderr, "shader cache: Dawn's copied from the title\n");
   }
   if (stat(TITLE_DIR "/radv-shader-cache/mesa_shader_cache_db", &status) != 0) {
      seed_folder(TITLE_DIR "/res/shader-cache/radv-shader-cache", TITLE_DIR "/radv-shader-cache");
      fprintf(stderr, "shader cache: the driver's copied from the title\n");
   }
}

/* /app0/env.txt: KEY=VALUE lines, the recomp's options for a test run
 * (ED_QUICKLOAD=saves/slot1.state, AURORA_GPU_TIME_LOG=1, ...), since the
 * console starts a title with no arguments or environment. Set for the C
 * library's getenv (the recomp) and in SDL's copy of the environment (Aurora). */
static void
load_env_file(void)
{
   char line[1024];
   FILE *file = fopen(TITLE_DIR "/env.txt", "r");

   if (file == NULL)
      return;
   while (fgets(line, sizeof(line), file) != NULL) {
      char *equals, *end = line + strcspn(line, "\r\n");

      *end = '\0';
      if (line[0] == '#' || (equals = strchr(line, '=')) == NULL || equals == line)
         continue;
      *equals = '\0';
      setenv(line, equals + 1, 1);
      SDL_SetEnvironmentVariable(SDL_GetEnvironment(), line, equals + 1, true);
      fprintf(stderr, "env.txt: %s=%s\n", line, equals + 1);
   }
   fclose(file);
}

__attribute__((constructor)) static void
ps5_startup(void)
{
   platform_init(PS5_TITLE_NAME);
   load_env_file();
   mkdir(CACHE_DIR, 0777);
   seed_shader_caches();
   /* SDL_GetPrefPath is $XDG_DATA_HOME/<org>/<app>/. A title sees its own folder
    * (/app0, which is /data/homebrew/<TITLE_ID>) and nothing else of /data, so
    * that is where they go. Set in SDL's own copy of the environment, which is
    * all SDL_getenv (and so Aurora's AURORA_CACHE_DIR) reads: the console's libc
    * keeps what setenv sets apart from the `environ` SDL copies. */
   SDL_SetEnvironmentVariable(SDL_GetEnvironment(), "XDG_DATA_HOME", TITLE_DIR "/userdata", true);
   SDL_SetEnvironmentVariable(SDL_GetEnvironment(), "HOME", TITLE_DIR "/userdata", true);
   SDL_SetEnvironmentVariable(SDL_GetEnvironment(), "AURORA_CACHE_DIR", CACHE_DIR, true);
}
