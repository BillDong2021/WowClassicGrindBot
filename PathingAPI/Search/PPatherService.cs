﻿using PathingAPI.WorldToMap;
using PatherPath.Graph;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Security.Cryptography.X509Certificates;
using System.Threading;
using WowTriangles;
using Newtonsoft.Json;
using PathingAPI.Data;

using SharedLib;
using SharedLib.Data;

namespace PathingAPI
{
    public class PPatherService
    {
        private readonly List<WorldMapArea> worldMapAreas;
        private Search search { get; set; }
        private readonly PatherPath.Logger logger;
        private readonly DataConfig dataConfig;
        private Action<Path> OnPathCreated;
        public Action<string> OnLog { get; set; }
        public Action OnReset { get; set; }
        public Action<ChunkAddedEventArgs> OnChunkAdded { get; set; }
        public Action<LinesEventArgs> OnLinesAdded { get; set; }
        public Action<SphereEventArgs> OnSphereAdded { get; set; }
        

        private Path lastPath;
        public bool HasInitialised;

        public PPatherService()
        {
            logger = new PatherPath.Logger((s)=>Log(s));
            dataConfig = DataConfig.Load();
            this.worldMapAreas = WorldMapAreaFactory.Read(logger, dataConfig);
        }

        public PPatherService(Action<string> onWrite, DataConfig dataConfig)
        {
            this.dataConfig = dataConfig;
            logger = new PatherPath.Logger(onWrite);
            this.worldMapAreas = WorldMapAreaFactory.Read(logger, dataConfig);
        }

        public void Log(string message)
        {
            try
            {
                Console.WriteLine(message);
                OnLog?.Invoke(message);
            }
            catch (Exception ex)
            {
                Log(ex.Message);
            }
        }

        public void Reset()
        {
            OnReset?.Invoke();
            this.search = null;
        }

        private bool Initialise(string continent)
        {
            if (search == null || continent != search.continent)
            {
                HasInitialised = true;
                PathGraph.SearchEnabled = false;
                search = new Search(continent, logger, dataConfig);
                search.PathGraph.triangleWorld.NotifyChunkAdded = (e) => OnChunkAdded?.Invoke(e);
                OnReset?.Invoke();
                return true;
            }
            return false;
        }
        public Location GetWorldLocation(int uiMapId, float v1, float v2, float z = 0)
        {
            var worldMapArea = worldMapAreas.First(i => i.UIMapId == uiMapId);
            var worldX = worldMapArea.ToWorldX(v2);
            var worldY = worldMapArea.ToWorldY(v1);

            Initialise(worldMapArea.Continent);

            var location = search.CreateLocation(worldX, worldY, z);
            location.Continent = worldMapArea.Continent;
            return location;
        }

        public WorldMapAreaSpot ToMapAreaSpot(float x, float y, float z, int mapHint)
        {
            var area = WorldMapAreaFactory.GetWorldMapArea(worldMapAreas, x, y, search.continent, mapHint);
            return new WorldMapAreaSpot
            {
                Y = area.ToMapX(x),
                X = area.ToMapY(y),
                Z = z,
                MapID = area.UIMapId
            };
        }

        public Path DoSearch(PathGraph.eSearchScoreSpot searchType)
        {
            var path = search.DoSearch(searchType);
            OnPathCreated?.Invoke(path);
            lastPath = path;
            return path;
        }

        public void Save()
        {
            search.PathGraph.Save();
        }

        public void SetOnPathCreated(Action<Path> action)
        {
            OnPathCreated = action;
            if (lastPath != null)
            {
                OnPathCreated?.Invoke(lastPath);
            }
        }

        public void SetOnLinesAdded(Action<Path> action)
        {
            OnPathCreated = action;
            if (lastPath != null)
            {
                OnPathCreated?.Invoke(lastPath);
            }
        }

        public bool SetLocations(Location from, Location to)
        {
            this.Initialise(from.Continent);

            bool hasChanged = this.search.locationFrom == null || this.search.locationTo == null ||
                from.X != this.search.locationFrom.X ||
                from.Y != this.search.locationFrom.Y ||
                to.X != this.search.locationTo.X ||
                to.Y != this.search.locationTo.Y;

            this.search.locationFrom = from;
            this.search.locationTo = to;

            return hasChanged;
        }

        public List<TriangleCollection> SetNotifyChunkAdded(Action<ChunkAddedEventArgs> action)
        {
            OnChunkAdded = action;

            if (search == null)
            {
                return new List<TriangleCollection>();
            }

            return search.PathGraph.triangleWorld.LoadedChunks;
        }

        public List<Spot> GetCurrentSearchPath()
        {
            if (search == null || search.PathGraph == null)
            {
                return null;
            }

            return search.PathGraph.CurrentSearchPath();
        }

        public Location SearchFrom => this.search?.locationFrom;

        public Location SearchTo => this.search?.locationTo;

        public Location ClosestLocation => this.search?.PathGraph?.ClosestSpot?.location;

        public Location PeekLocation => this.search?.PathGraph?.PeekSpot?.location;

        public void DrawPath(string continent, List<float[]> coords)
        {
            var first = coords[0];
            var last = coords[^1];

            var fromLoc = new Location(first[0], first[1], first[2], "l1", continent);
            var toLoc = new Location(last[0], last[1], last[2], "l2", continent);

            SetLocations(fromLoc, toLoc);

            if (search.PathGraph == null)
            {
                search.CreatePathGraph(continent);
            }

            List<Spot> spots = new List<Spot>();
            for (int i = 0; i < coords.Count; i++)
            {
                Location l = new Location(coords[i][0], coords[i][1], coords[i][2], "l" + i.ToString(), continent);
                Spot spot = new Spot(l);
                spots.Add(spot);
                search.PathGraph.CreateSpotsAroundSpot(spot, false);
            }

            var path = new Path(spots);
            OnPathCreated?.Invoke(path);
        }
    }
}