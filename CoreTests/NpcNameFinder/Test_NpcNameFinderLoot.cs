﻿using System.Drawing;
using Core.Goals;
using Microsoft.Extensions.Logging;
using SharedLib;
using SharedLib.NpcFinder;
using System.Threading;

namespace CoreTests
{
    public class Test_NpcNameFinderLoot
    {
        private readonly ILogger logger;
        private readonly NpcNameFinder npcNameFinder;
        private readonly NpcNameTargeting npcNameTargeting;
        private readonly RectProvider rectProvider;
        private readonly DirectBitmapCapturer capturer;

        public Test_NpcNameFinderLoot(ILogger logger)
        {
            this.logger = logger;

            MockWoWProcess mockWoWProcess = new MockWoWProcess();
            rectProvider = new RectProvider();
            rectProvider.GetRectangle(out var rect);
            capturer = new DirectBitmapCapturer(rect);

            npcNameFinder = new NpcNameFinder(logger, capturer, new AutoResetEvent(false));
            npcNameTargeting = new NpcNameTargeting(logger, npcNameFinder, mockWoWProcess);
        }

        public void Execute()
        {
            npcNameFinder.ChangeNpcType(NpcNames.Corpse);

            capturer.Capture();

            System.Diagnostics.Stopwatch stopwatch = new System.Diagnostics.Stopwatch();
            stopwatch.Start();
            this.npcNameFinder.Update();
            stopwatch.Stop();
            logger.LogInformation($"Update: {stopwatch.ElapsedMilliseconds}ms");

            var bitmap = capturer.GetBitmap(capturer.Rect.Width, capturer.Rect.Height);

            using (var gr = Graphics.FromImage(bitmap))
            {
                Font drawFont = new Font("Arial", 10);
                SolidBrush drawBrush = new SolidBrush(Color.White);

                if (npcNameFinder.Npcs.Count > 0)
                {
                    using (var whitePen = new Pen(Color.White, 1))
                    {
                        gr.DrawRectangle(whitePen, npcNameFinder.Area);

                        npcNameFinder.Npcs.ForEach(n =>
                        {
                            npcNameTargeting.locFindByCursorType.ForEach(l =>
                            {
                                gr.DrawEllipse(whitePen, l.X + n.ClickPoint.X, l.Y + n.ClickPoint.Y, 5, 5);
                            });
                        });


                        npcNameFinder.Npcs.ForEach(n => gr.DrawRectangle(whitePen, new Rectangle(n.Min, new Size(n.Width, n.Height))));
                        npcNameFinder.Npcs.ForEach(n => gr.DrawString(npcNameFinder.Npcs.IndexOf(n).ToString(), drawFont, drawBrush, new PointF(n.Min.X - 20f, n.Min.Y)));
                    }
                }
            }

            npcNameFinder.Npcs.ForEach(n =>
            {
                logger.LogInformation($"{npcNameFinder.Npcs.IndexOf(n),2} -> rect={new Rectangle(n.Min.X, n.Min.Y, n.Width, n.Height)} ClickPoint={{{n.ClickPoint.X,4},{n.ClickPoint.Y,4}}}");
            });

            logger.LogInformation("\n");

            bitmap.Save("loot_names.png");
        }
    }
}
