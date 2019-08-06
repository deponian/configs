//////////////////////////////////////////////////////////////////////////////////////
// Workspace Switch Notifier                                                        //
// Shows a OSD with workspace name on workspace switching action                    //
//                                                                                  //
// wsn.c -                                                                          //
//                                                                                  //
// Authors:                                                                         //
//    Isaac Maia Pessoa                                                             //
//                                                                                  //
// This program is free software: you can redistribute it and/or modify it          //
// under the terms of the GNU General Public License version 3, as published        //
// by the Free Software Foundation.                                                 //
//                                                                                  //
// This program is distributed in the hope that it will be useful, but              //
// WITHOUT ANY WARRANTY; without even the implied warranties of                     //
// MERCHANTABILITY, SATISFACTORY QUALITY, or FITNESS FOR A PARTICULAR               //
// PURPOSE.  See the GNU General Public License for more details.                   //
//                                                                                  //
// You should have received a copy of the GNU General Public License along          //
// with this program.  If not, see <http://www.gnu.org/licenses/>.                  //
//////////////////////////////////////////////////////////////////////////////////////

#include <libnotify/notify.h>
#include <libwnck/libwnck.h>

#define N_SUMMARY "Workspace Changed"
#define N_ICON    "dialog-information"
#define N_APPNAME "workspace switch notifier"
#define N_TIMEOUT 2000 /*2000ms = 2s */

static NotifyNotification * m_notification = NULL;

static void
on_active_workspace_changed (WnckScreen    *screen,
                             WnckWorkspace *space,
                             gpointer      data)
{

  WnckWorkspace * active_workspace = wnck_screen_get_active_workspace(screen);
  const char * w_name = wnck_workspace_get_name (active_workspace);

  notify_notification_update(m_notification, N_SUMMARY, w_name, N_ICON);
  notify_notification_show(m_notification, NULL);
}

int main(int argc, char ** argv)
{

   GMainLoop *loop;   
   WnckScreen *screen;

   if (notify_init(N_APPNAME))
       m_notification = notify_notification_new(N_SUMMARY, "" , N_ICON);
   else
       fprintf(stderr, "Failed to init notifications\n");
   notify_notification_set_timeout(m_notification, N_TIMEOUT);

   gdk_init (&argc, &argv);

   loop = g_main_loop_new (NULL, FALSE);
   screen = wnck_screen_get_default();

   g_signal_connect (screen, "active-workspace-changed",
                    G_CALLBACK (on_active_workspace_changed), NULL);

   g_main_loop_run (loop);

   g_main_loop_unref (loop);    

   return 0;
}