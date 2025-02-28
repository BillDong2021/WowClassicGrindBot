﻿using System;
using System.Collections.Generic;
using System.Threading.Tasks;
using Microsoft.Extensions.Logging;
using Core.PPather;
using Core.Database;
using System.Threading;
using System.Diagnostics;
using AnTCP.Client;
using SharedLib;
using System.Numerics;

namespace Core
{
    public sealed class RemotePathingAPIV3 : IPPather
    {
        public enum EMessageType
        {
            PATH,
            MOVE_ALONG_SURFACE,
            RANDOM_POINT,
            RANDOM_POINT_AROUND,
            CAST_RAY,
            RANDOM_PATH
        }
        public enum PathRequestFlags : int
        {
            NONE = 0,
            CHAIKIN = 1,
            CATMULLROM = 2,
            FIND_LOCATION = 4
        };


        private readonly ILogger logger;
        private readonly WorldMapAreaDB worldMapAreaDB;
        private readonly bool debug = false;

        // TODO remove this
        private int watchdogPollMs = 1000;

        private List<LineArgs> lineArgs = new List<LineArgs>();

        private AnTcpClient Client { get; }
        private Thread ConnectionWatchdog { get; }

        private bool ShouldExit { get; set; }

        public RemotePathingAPIV3(ILogger logger, string ip, int port, WorldMapAreaDB worldMapAreaDB)
        {
            this.logger = logger;
            this.worldMapAreaDB = worldMapAreaDB;

            Client = new AnTcpClient(ip, port);
            ConnectionWatchdog = new Thread(ObserveConnection);
            ConnectionWatchdog.Start();
        }

        #region old

        public ValueTask DrawLines(List<LineArgs> lineArgs)
        {
            return ValueTask.CompletedTask;
        }

        public ValueTask DrawLines()
        {
            return DrawLines(lineArgs);
        }

        public ValueTask DrawSphere(SphereArgs args)
        {
            return ValueTask.CompletedTask;
        }

        public ValueTask<List<Vector3>> FindRoute(int uiMapId, Vector3 fromPoint, Vector3 toPoint)
        {
            if (!Client.IsConnected)
            {
                return new ValueTask<List<Vector3>>();
            }

            try
            {
                Vector3 start = worldMapAreaDB.GetWorldLocation(uiMapId, fromPoint, true);
                Vector3 end = worldMapAreaDB.GetWorldLocation(uiMapId, toPoint, true);

                var result = new List<Vector3>();

                if (!worldMapAreaDB.TryGet(uiMapId, out WorldMapArea area))
                    return new ValueTask<List<Vector3>>(result);

                // incase haven't asked a pathfinder for a route this value will be 0
                // that case use the highest location
                if (start.Z == 0)
                {
                    start.Z = area.LocTop / 2;
                    end.Z = area.LocTop / 2;
                }

                if (debug)
                    logger.LogInformation($"Finding route from {fromPoint}({start}) map {uiMapId} to {toPoint}({end}) map {uiMapId}...");

                var path = Client.Send((byte)EMessageType.PATH, (area.MapID, PathRequestFlags.FIND_LOCATION | PathRequestFlags.CATMULLROM, start, end)).AsArray<Vector3>();
                if (path.Length == 1 && path[0] == Vector3.Zero)
                    return new ValueTask<List<Vector3>>(result);

                for (int i = 0; i < path.Length; i++)
                {
                    if (debug)
                        logger.LogInformation($"new float[] {{ {path[i].X}f, {path[i].Y}f, {path[i].Z}f }},");

                    Vector3 point = worldMapAreaDB.ToAreaLoc(path[i].X, path[i].Y, path[i].Z, area.Continent, uiMapId);
                    result.Add(point);
                }

                return new ValueTask<List<Vector3>>(result);
            }
            catch (Exception ex)
            {
                logger.LogError(ex, $"Finding route from {fromPoint} to {toPoint}");
                Console.WriteLine(ex);
                return new ValueTask<List<Vector3>>();
            }
        }


        public Task<bool> PingServer()
        {
            CancellationTokenSource cts = new CancellationTokenSource();

            var task = Task.Run(() =>
            {
                cts.CancelAfter(2 * watchdogPollMs);
                Stopwatch sw = Stopwatch.StartNew();

                while (!cts.IsCancellationRequested)
                {
                    if (Client.IsConnected)
                    {
                        break;
                    }
                }

                sw.Stop();

                logger.LogInformation($"{nameof(RemotePathingAPIV3)} PingServer {sw.ElapsedMilliseconds}ms {Client.IsConnected}");

                return Client.IsConnected;
            });

            return task;
        }

        public void RequestDisconnect()
        {
            ShouldExit = true;
            ConnectionWatchdog.Join();
        }

        #endregion old

        private void ObserveConnection()
        {
            while (!ShouldExit)
            {
                if (!Client.IsConnected)
                {
                    try
                    {
                        Client.Connect();
                    }
                    catch
                    {
                        // ignored, will happen when we cant connect
                    }
                }

                Thread.Sleep(watchdogPollMs);
            }
        }

    }
}