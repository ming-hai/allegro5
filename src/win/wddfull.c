/*         ______   ___    ___ 
 *        /\  _  \ /\_ \  /\_ \ 
 *        \ \ \L\ \\//\ \ \//\ \      __     __   _ __   ___ 
 *         \ \  __ \ \ \ \  \ \ \   /'__`\ /'_ `\/\`'__\/ __`\
 *          \ \ \/\ \ \_\ \_ \_\ \_/\  __//\ \L\ \ \ \//\ \L\ \
 *           \ \_\ \_\/\____\/\____\ \____\ \____ \ \_\\ \____/
 *            \/_/\/_/\/____/\/____/\/____/\/___L\ \/_/ \/___/
 *                                           /\____/
 *                                           \_/__/
 *
 *      DirectDraw gfx fullscreen drivers.
 *
 *      By Stefan Schimanski.
 *
 *      See readme.txt for copyright information.
 */


#include "wddraw.h"


static struct BITMAP *init_directx_accel(int w, int h, int v_w, int v_h, int color_depth);
static struct BITMAP *init_directx_soft(int w, int h, int v_w, int v_h, int color_depth);
static struct BITMAP *init_directx_safe(int w, int h, int v_w, int v_h, int color_depth);


GFX_DRIVER gfx_directx_accel =
{
   GFX_DIRECTX_ACCEL,
   empty_string,
   empty_string,
   "DirectDraw accel",
   init_directx_accel,
   gfx_directx_exit,
   NULL,                         // AL_METHOD(int, scroll, (int x, int y)); 
   gfx_directx_sync,
   gfx_directx_set_palette,
   NULL,                         // AL_METHOD(int, request_scroll, (int x, int y));
   NULL,                         // AL_METHOD(int, poll_scroll, (void));
   NULL,                         // AL_METHOD(void, enable_triple_buffer, (void));
   gfx_directx_create_video_bitmap,
   gfx_directx_destroy_video_bitmap,
   gfx_directx_show_video_bitmap,
   gfx_directx_request_video_bitmap,
   gfx_directx_create_system_bitmap,
   gfx_directx_destroy_system_bitmap,
   NULL,                         // AL_METHOD(int, set_mouse_sprite, (struct BITMAP *sprite, int xfocus, int yfocus));
   NULL,                         // AL_METHOD(int, show_mouse, (struct BITMAP *bmp, int x, int y));
   NULL,                         // AL_METHOD(void, hide_mouse, (void));
   NULL,                         // AL_METHOD(void, move_mouse, (int x, int y));
   NULL,                         // AL_METHOD(void, drawing_mode, (void));
   NULL,                         // AL_METHOD(void, save_video_state, (void*));
   NULL,                         // AL_METHOD(void, restore_video_state, (void*));
   gfx_directx_fetch_mode_list,
   0, 0,                         // physical (not virtual!) screen size
   TRUE,                         // true if video memory is linear
   0,                            // bank size, in bytes
   0,                            // bank granularity, in bytes
   0,                            // video memory size, in bytes
   0,                            // physical address of video memory
   FALSE                         // true if driver runs windowed
};


GFX_DRIVER gfx_directx_soft =
{
   GFX_DIRECTX_SOFT,
   empty_string,
   empty_string,
   "DirectDraw soft",
   init_directx_soft,
   gfx_directx_exit,
   NULL,                        // AL_METHOD(int, scroll, (int x, int y)); 
   gfx_directx_sync,
   gfx_directx_set_palette,
   NULL,                        // AL_METHOD(int, request_scroll, (int x, int y));
   NULL,                        // AL_METHOD(int, poll_scroll, (void));
   NULL,                        // AL_METHOD(void, enable_triple_buffer, (void));
   gfx_directx_create_video_bitmap,
   gfx_directx_destroy_video_bitmap,
   gfx_directx_show_video_bitmap,
   gfx_directx_request_video_bitmap,
   gfx_directx_create_system_bitmap,
   gfx_directx_destroy_system_bitmap,
   NULL,                        // AL_METHOD(int, set_mouse_sprite, (struct BITMAP *sprite, int xfocus, int yfocus));
   NULL,                        // AL_METHOD(int, show_mouse, (struct BITMAP *bmp, int x, int y));
   NULL,                        // AL_METHOD(void, hide_mouse, (void));
   NULL,                        // AL_METHOD(void, move_mouse, (int x, int y));
   NULL,                        // AL_METHOD(void, drawing_mode, (void));
   NULL,                        // AL_METHOD(void, save_video_state, (void*));
   NULL,                        // AL_METHOD(void, restore_video_state, (void*));
   gfx_directx_fetch_mode_list,
   0, 0,                        // physical (not virtual!) screen size
   TRUE,                        // true if video memory is linear
   0,                           // bank size, in bytes
   0,                           // bank granularity, in bytes
   0,                           // video memory size, in bytes
   0,                           // physical address of video memory
   FALSE                        // true if driver runs windowed
};


GFX_DRIVER gfx_directx_safe =
{
   GFX_DIRECTX_SAFE,
   empty_string,
   empty_string,
   "DirectDraw safe",
   init_directx_safe,
   gfx_directx_exit,
   NULL,                        // AL_METHOD(int, scroll, (int x, int y)); 
   gfx_directx_sync,
   gfx_directx_set_palette,
   NULL,                        // AL_METHOD(int, request_scroll, (int x, int y));
   NULL,                        // AL_METHOD(int, poll_scroll, (void));
   NULL,                        // AL_METHOD(void, enable_triple_buffer, (void));
   NULL, NULL, NULL, NULL, NULL, NULL,
   NULL,                        // AL_METHOD(int, set_mouse_sprite, (struct BITMAP *sprite, int xfocus, int yfocus));
   NULL,                        // AL_METHOD(int, show_mouse, (struct BITMAP *bmp, int x, int y));
   NULL,                        // AL_METHOD(void, hide_mouse, (void));
   NULL,                        // AL_METHOD(void, move_mouse, (int x, int y));
   NULL,                        // AL_METHOD(void, drawing_mode, (void));
   NULL,                        // AL_METHOD(void, save_video_state, (void*));
   NULL,                        // AL_METHOD(void, restore_video_state, (void*));
   gfx_directx_fetch_mode_list,
   0, 0,                        // physical (not virtual!) screen size
   TRUE,                        // true if video memory is linear
   0,                           // bank size, in bytes
   0,                           // bank granularity, in bytes
   0,                           // video memory size, in bytes
   0,                           // physical address of video memory
   FALSE                        // true if driver runs windowed
};



static WIN_GFX_DRIVER win_gfx_fullscreen =
{
   FALSE,                       // true if driver has backing store
   gfx_directx_restore,
   NULL,                        // AL_METHOD(void, switch_out, (void));
   NULL,                        // AL_METHOD(void, enter_sysmode, (void));
   NULL,                        // AL_METHOD(void, exit_sysmode, (void));
   NULL,                        // AL_METHOD(void, move, (int x, int y, int w, int h));
   NULL,                        // AL_METHOD(void, iconify, (void));
   NULL                         // AL_METHOD(void, paint, (RECT *));
};



/* finalize_fullscreen_init:
 */
static void finalize_fullscreen_init(void)
{
   /* connect to the system driver */
   win_gfx_driver = &win_gfx_fullscreen;

   /* set the default switching policy */
   set_display_switch_mode(SWITCH_AMNESIA);

   /* grab input devices */
   win_grab_input();
}



/* init_directx_accel:
 */
static struct BITMAP *init_directx_accel(int w, int h, int v_w, int v_h, int color_depth)
{
   struct BITMAP *bmp;

   _enter_critical();

   bmp = gfx_directx_init(&gfx_directx_accel, TRUE, w, h, v_w, v_h, color_depth);

   if (bmp)
      finalize_fullscreen_init();

   _exit_critical();

   return bmp;
}



/* init_directx_soft:
 */
static struct BITMAP *init_directx_soft(int w, int h, int v_w, int v_h, int color_depth)
{
   struct BITMAP *bmp;

   _enter_critical();

   bmp = gfx_directx_init(&gfx_directx_soft, FALSE, w, h, v_w, v_h, color_depth);

   if (bmp)
      finalize_fullscreen_init();

   _exit_critical();

   return bmp;
}



/* init_directx_safe:
 */
static struct BITMAP *init_directx_safe(int w, int h, int v_w, int v_h, int color_depth)
{
   struct BITMAP *bmp;

   _enter_critical();

   bmp = gfx_directx_init(&gfx_directx_safe, FALSE, w, h, v_w, v_h, color_depth);

   if (bmp)
      finalize_fullscreen_init();

   _exit_critical();

   return bmp;
}

