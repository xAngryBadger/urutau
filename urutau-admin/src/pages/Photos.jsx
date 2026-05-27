import React, { useEffect, useState, useCallback, startTransition } from 'react';
import { fetchAllParcels, getPhotoUrl } from '../services/pocketbase';
import safeError from '../services/logger';
import {
  Image,
  Download,
  X,
  ChevronLeft,
  ChevronRight,
  Grid,
  List,
  Search,
  Loader2,
  ZoomIn
} from 'lucide-react';

const Photos = () => {
  const [parcels, setParcels] = useState([]);
  const [photos, setPhotos] = useState([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(null);
  const [selectedPhoto, setSelectedPhoto] = useState(null);
  const [viewMode, setViewMode] = useState('grid');
  const [searchTerm, setSearchTerm] = useState('');
  const [actionError, setActionError] = useState(null);

  const loadPhotos = useCallback(async () => {
    try {
      startTransition(() => { setLoading(true); setError(null); });
      const result = await fetchAllParcels({ hasPhotos: true });

      const allPhotos = [];
      result.forEach((parcel) => {
        if (parcel.fotos_parcela && parcel.fotos_parcela.length > 0) {
          parcel.fotos_parcela.forEach((photoId, index) => {
            const url = getPhotoUrl(parcel, index);
            if (!url) {
              return;
            }

            allPhotos.push({
              id: `${parcel.id}_${index}`,
              photoId,
              parcelId: parcel.id,
              parcelNumber: parcel.id_parcela,
              property: parcel.propertyCode || '',
              ut: parcel.utCode || '',
              url,
              user: parcel.displayUser || '',
              date: parcel.createdAt,
            });
          });
        }
      });

      startTransition(() => {
        setParcels(result);
        setPhotos(allPhotos);
      });
    } catch (err) {
      startTransition(() => setError('Erro ao carregar fotos. Tente novamente.'));
      safeError('Error loading photos:', err);
    } finally {
      startTransition(() => setLoading(false));
    }
  }, []);

  useEffect(() => {
    startTransition(() => { loadPhotos(); });
  }, [loadPhotos]);

  useEffect(() => {
    if (!actionError) return;
    const id = setTimeout(() => setActionError(null), 5000);
    return () => clearTimeout(id);
  }, [actionError]);

  const filteredPhotos = photos.filter(photo => 
    (photo.property || '').toLowerCase().includes(searchTerm.toLowerCase()) ||
    (photo.ut || '').toLowerCase().includes(searchTerm.toLowerCase()) ||
    String(photo.parcelNumber).includes(searchTerm)
  );

  const openPhotoViewer = (photo) => {
    setSelectedPhoto(photo);
  };

  const closePhotoViewer = () => {
    setSelectedPhoto(null);
  };

  const navigatePhoto = (direction) => {
    const currentIndex = filteredPhotos.findIndex(p => p.id === selectedPhoto.id);
    const newIndex = direction === 'next' 
      ? (currentIndex + 1) % filteredPhotos.length
      : (currentIndex - 1 + filteredPhotos.length) % filteredPhotos.length;
    setSelectedPhoto(filteredPhotos[newIndex]);
  };

  const downloadPhoto = async (photo) => {
    try {
      const response = await fetch(photo.url);
      const blob = await response.blob();
      const link = document.createElement('a');
      link.href = URL.createObjectURL(blob);
      link.download = `parcela_${photo.parcelNumber}_${photo.property}.jpg`;
      link.click();
    } catch (err) {
      safeError('Download error:', err);
      setActionError('Erro ao baixar foto');
    }
  };

  return (
    <div className="space-y-6">
      {actionError && (
        <div className="mb-4 p-4 bg-red-50 border border-red-200 rounded-lg flex items-center justify-between">
          <p className="text-red-700 text-sm">{actionError}</p>
          <button onClick={() => setActionError(null)} className="text-red-500 hover:text-red-700">
            <X className="h-4 w-4" />
          </button>
        </div>
      )}

      {/* Header */}
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-3xl font-bold text-gray-900">Galeria de Fotos</h1>
          <p className="text-gray-600 mt-1">
            {photos.length} fotos de {parcels.length} parcelas
          </p>
        </div>
        <div className="flex items-center gap-3">
          <div className="relative">
            <Search className="absolute left-3 top-1/2 -translate-y-1/2 h-4 w-4 text-gray-400" />
            <input
              type="text"
              placeholder="Buscar por propriedade, UT..."
              value={searchTerm}
              onChange={(e) => setSearchTerm(e.target.value)}
              className="input-field pl-10 w-72"
            />
          </div>
          <div className="flex bg-gray-100 rounded-lg p-1">
            <button
              onClick={() => setViewMode('grid')}
              className={`p-2 rounded ${viewMode === 'grid' ? 'bg-white shadow-sm text-forest-700' : 'text-gray-500'}`}
            >
              <Grid className="h-4 w-4" />
            </button>
            <button
              onClick={() => setViewMode('list')}
              className={`p-2 rounded ${viewMode === 'list' ? 'bg-white shadow-sm text-forest-700' : 'text-gray-500'}`}
            >
              <List className="h-4 w-4" />
            </button>
          </div>
        </div>
      </div>

      {/* Photo Gallery */}
  {loading ? (
    <div className="flex items-center justify-center h-64">
      <Loader2 className="h-8 w-8 animate-spin text-forest-600" />
    </div>
  ) : error ? (
    <div className="bg-red-50 border border-red-200 rounded-xl p-6 text-center">
      <p className="text-red-700">{error}</p>
      <button onClick={loadPhotos} className="mt-4 btn-secondary">
        Tentar novamente
      </button>
    </div>
  ) : filteredPhotos.length === 0 ? (
        <div className="text-center py-16">
          <Image className="h-16 w-16 mx-auto text-gray-300 mb-4" />
          <p className="text-gray-500">Nenhuma foto encontrada</p>
        </div>
      ) : viewMode === 'grid' ? (
        <div className="grid grid-cols-2 md:grid-cols-3 lg:grid-cols-4 xl:grid-cols-5 gap-4">
          {filteredPhotos.map((photo) => (
            <div
              key={photo.id}
              className="group relative aspect-square bg-gray-100 rounded-lg overflow-hidden cursor-pointer hover:ring-2 hover:ring-forest-500 transition-all"
              onClick={() => openPhotoViewer(photo)}
            >
              <img
                src={photo.url}
                alt={`Parcela ${photo.parcelNumber}`}
                className="w-full h-full object-cover transition-transform group-hover:scale-105"
                loading="lazy"
              />
              <div className="absolute inset-0 bg-gradient-to-t from-black/70 via-transparent to-transparent opacity-0 group-hover:opacity-100 transition-opacity">
                <div className="absolute bottom-0 left-0 right-0 p-3 text-white">
                  <p className="font-medium text-sm">{photo.property}</p>
                  <p className="text-xs opacity-90">Parcela {String(photo.parcelNumber).padStart(3, '0')}</p>
                </div>
                <button
                  onClick={(e) => {
                    e.stopPropagation();
                    downloadPhoto(photo);
                  }}
                  className="absolute top-2 right-2 p-2 bg-white/20 backdrop-blur-sm rounded-full hover:bg-white/40 transition-colors"
                >
                  <Download className="h-4 w-4 text-white" />
                </button>
              </div>
            </div>
          ))}
        </div>
      ) : (
        <div className="card">
          <div className="overflow-x-auto">
            <table className="min-w-full divide-y divide-gray-200">
              <thead className="bg-gray-50">
                <tr>
                  <th className="table-header">Foto</th>
                  <th className="table-header">Propriedade</th>
                  <th className="table-header">UT</th>
                  <th className="table-header">Parcela</th>
                  <th className="table-header">Usuário</th>
                  <th className="table-header">Data</th>
                  <th className="table-header">Ações</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-gray-200">
                {filteredPhotos.map((photo) => (
                  <tr key={photo.id} className="hover:bg-gray-50">
                    <td className="px-6 py-4">
                      <img
                        src={photo.url}
                        alt={`Parcela ${photo.parcelNumber}`}
                        className="h-16 w-16 object-cover rounded-lg cursor-pointer"
                        onClick={() => openPhotoViewer(photo)}
                      />
                    </td>
                    <td className="table-cell">{photo.property}</td>
                    <td className="table-cell">{photo.ut}</td>
                    <td className="table-cell">
                      <span className="font-mono bg-gray-100 px-2 py-1 rounded">
                        {String(photo.parcelNumber).padStart(3, '0')}
                      </span>
                    </td>
                    <td className="table-cell">{photo.user}</td>
                    <td className="table-cell text-gray-500">
                      {photo.date ? new Date(photo.date).toLocaleDateString('pt-BR') : '-'}
                    </td>
                    <td className="table-cell">
                      <button
                        onClick={() => downloadPhoto(photo)}
                        className="text-forest-600 hover:text-forest-800"
                      >
                        <Download className="h-4 w-4" />
                      </button>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        </div>
      )}

      {/* Photo Viewer Modal */}
      {selectedPhoto && (
        <div className="photo-modal" onClick={closePhotoViewer}>
          <button
            onClick={closePhotoViewer}
            className="absolute top-4 right-4 p-2 text-white/80 hover:text-white z-10"
          >
            <X className="h-8 w-8" />
          </button>
          
          <button
            onClick={(e) => {
              e.stopPropagation();
              navigatePhoto('prev');
            }}
            className="absolute left-4 top-1/2 -translate-y-1/2 p-2 text-white/80 hover:text-white"
          >
            <ChevronLeft className="h-10 w-10" />
          </button>
          
          <button
            onClick={(e) => {
              e.stopPropagation();
              navigatePhoto('next');
            }}
            className="absolute right-4 top-1/2 -translate-y-1/2 p-2 text-white/80 hover:text-white"
          >
            <ChevronRight className="h-10 w-10" />
          </button>

          <div 
            className="max-w-5xl max-h-[85vh] relative"
            onClick={(e) => e.stopPropagation()}
          >
            <img
              src={selectedPhoto.url}
              alt={`Parcela ${selectedPhoto.parcelNumber}`}
              className="max-w-full max-h-[80vh] object-contain rounded-lg"
            />
            
            <div className="bg-black/50 backdrop-blur-sm text-white p-4 rounded-lg mt-4">
              <div className="flex items-center justify-between">
                <div>
                  <p className="font-medium">{selectedPhoto.property} - {selectedPhoto.ut}</p>
                  <p className="text-sm opacity-80">
                    Parcela {String(selectedPhoto.parcelNumber).padStart(3, '0')} • 
                    {' '}{selectedPhoto.user} • 
                    {' '}{selectedPhoto.date ? new Date(selectedPhoto.date).toLocaleDateString('pt-BR') : '-'}
                  </p>
                </div>
                <button
                  onClick={() => downloadPhoto(selectedPhoto)}
                  className="flex items-center gap-2 bg-white/20 hover:bg-white/30 px-4 py-2 rounded-lg transition-colors"
                >
                  <Download className="h-4 w-4" />
                  Baixar
                </button>
              </div>
            </div>
          </div>
        </div>
      )}
    </div>
  );
};

export default Photos;
