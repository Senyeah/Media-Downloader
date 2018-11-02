import { Injectable } from '@angular/core';
import { Observable, of } from 'rxjs';

import { Media } from './media';
import { MEDIA } from './mock-media';

@Injectable({
  providedIn: 'root'
})
export class MediaService {

  get media(): Observable<Media[]> {
    return of(MEDIA);
  }

  constructor() { }

}
